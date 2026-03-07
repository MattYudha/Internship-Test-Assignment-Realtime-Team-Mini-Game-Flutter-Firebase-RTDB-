"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onMatchStart = void 0;
const database_1 = require("firebase-functions/v2/database");
const admin = require("firebase-admin");
admin.initializeApp();
/**
 * Cloud Function: onMatchStart
 *
 * Trigger: Fires whenever /matches/{matchId}/meta is updated.
 * Triggered at the /meta level (not /meta/status) so that the ENTIRE meta object
 * — including the server-resolved 'startAt' timestamp — arrives in the event
 * payload IN MEMORY, eliminating the need for an extra .once("value") round-trip.
 *
 * Lifecycle:
 *  1. Check that status specifically transitioned from 'waiting' → 'running'.
 *  2. Extract startAt directly from event.data.after.val() (zero extra DB reads).
 *  3. Write endAt = startAt + 300_000 IMMEDIATELY so Flutter clients can start
 *     their countdown timers within milliseconds of match start.
 *  4. THEN wait 5 minutes (the game's actual duration).
 *  5. Set status to 'ended'.
 *
 * ⚠️  Anti-Pattern Note (setTimeout):
 *  Using await setTimeout(300_000) keeps this function instance alive for the
 *  entire game duration and incurs continuous compute billing. In a strict
 *  production environment, Firebase Cloud Tasks or Pub/Sub scheduling should be
 *  used instead. This pattern is intentionally kept here for local emulator
 *  validation where billing is not a concern.
 *
 *  timeoutSeconds is set to 540 (Google Cloud max) to safely cover the 5-minute
 *  wait plus execution overhead.
 */
exports.onMatchStart = (0, database_1.onValueUpdated)({
    ref: "/matches/{matchId}/meta",
    timeoutSeconds: 540,
}, async (event) => {
    const before = event.data.before.val();
    const after = event.data.after.val();
    // Guard: Only process the specific 'waiting' → 'running' transition.
    if (before?.status !== "waiting" || after?.status !== "running") {
        return;
    }
    const matchId = event.params.matchId;
    functions_logger_info(`[MATCH MANAGER] Match ${matchId} is now running. Computing endAt in-memory...`);
    // Extract startAt directly from the payload — no extra DB round-trip.
    // Firebase has already resolved ServerValue.timestamp by the time this
    // function receives the event, so after.startAt is a concrete number.
    const startAt = after.startAt ?? Date.now();
    const endAt = startAt + 300000; // Exactly 5 minutes in milliseconds
    const matchMetaRef = event.data.after.ref;
    // Write endAt IMMEDIATELY so Flutter clients receive the absolute server
    // timestamp and can begin their countdown timers right away.
    await matchMetaRef.update({ endAt });
    functions_logger_info(`[MATCH MANAGER] Match ${matchId}: endAt written (${new Date(endAt).toISOString()}). Starting 5-minute countdown...`);
    // Wait for the game duration (300 seconds).
    // See Anti-Pattern Note above.
    await new Promise((resolve) => setTimeout(resolve, 300000));
    // Re-check whether the match is still running before ending it.
    // The host may have ended the match early.
    const currentSnap = await matchMetaRef.child("status").once("value");
    const currentStatus = currentSnap.val();
    if (currentStatus === "running") {
        functions_logger_info(`[MATCH MANAGER] Time expired for match ${matchId}. Setting status to ended.`);
        await matchMetaRef.update({ status: "ended" });
        // Prof's Rule #10: Reset system/waiting_match when match ends
        // 12️⃣ Reopen app flow: Clean up so subsequent launches create a new match
        const sysRef = admin.database().ref("system/waiting_match");
        const sysSnap = await sysRef.once("value");
        if (sysSnap.val() === matchId) {
            await sysRef.remove();
        }
    }
    else {
        functions_logger_info(`[MATCH MANAGER] Match ${matchId} was already resolved (status: ${currentStatus}). Skipping.`);
    }
});
// Minimal logger wrapper to avoid importing the whole functions namespace
// just for the logger (compatible with modular v2 import style).
const functions_logger_info = (message) => {
    console.info(message);
};
//# sourceMappingURL=index.js.map