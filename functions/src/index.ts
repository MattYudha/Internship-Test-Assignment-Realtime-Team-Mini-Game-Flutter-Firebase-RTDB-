import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

/**
 * Cloud Function to manage match lifecycle.
 * Triggers when a match changes status. If it changes to 'running',
 * it schedules an automatic termination after 5 minutes.
 * 
 * Note: Configured with 320 seconds timeout to accommodate the 5-minute wait.
 * In a strict production environment, Google Cloud Tasks is preferred for scheduling,
 * but this delayed execution is perfect for Firebase Local Emulator validation.
 */
export const onMatchStart = functions
    .runWith({ timeoutSeconds: 320 })
    .database.ref("/matches/{matchId}/meta/status")
    .onUpdate(async (change, context) => {
        const after = change.after.val();

        // Only trigger when status specifically changes to 'running'
        if (after === "running") {
            const matchId = context.params.matchId;
            functions.logger.info(`[MATCH MANAGER] Match ${matchId} began. Auto-scheduling end trigger in 5 minutes...`);

            // Wait 5 minutes (300,000 ms)
            await new Promise((resolve) => setTimeout(resolve, 300000));

            // Re-check current status to ensure it hasn't been ended early by host
            const currentStatus = (await change.after.ref.once("value")).val();

            if (currentStatus === "running") {
                functions.logger.info(`[MATCH MANAGER] Time expired for match ${matchId}. Terminating now.`);
                await change.after.ref.set("ended");
            } else {
                functions.logger.info(`[MATCH MANAGER] Match ${matchId} was already resolved.`);
            }
        }
    });
