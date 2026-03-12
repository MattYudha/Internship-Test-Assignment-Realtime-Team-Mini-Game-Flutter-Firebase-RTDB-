# AI Usage Documentation

This file documents the AI-assisted development process for the **Realtime Tower Mini-Game** as per the assignment requirements.

## 1. AI Tools Used
*   **Gemini / Antigravity (Google DeepMind):** Used as the primary agentic coding assistant to architect, plan, and generate the Flutter clean architecture structure.

## 2. Aspects Assisted by AI

### Architecture & Planning
*   **Clean Architecture Scaffold:** AI designed the separation of concerns (Core, Domain, Data, Presentation layers).
*   **Data Models:** Structuring the realtime database JSON nodes to avoid mass collisions.
*   **State Management:** Integrating GetX for reactive updates and dependency injection.

### Algorithmic Optimization
*   **BFS Threading:** During initial planning, AI identified that Breadth-First Search on a 0-200,000 bounds would freeze Dart's single-threaded nature. AI suggested and implemented `Isolate.run()` using `compute()` to push the calculations to background threads. This was paramount for the Bot Simulation mode.

### Backend & Concurrency (Debugging / Addressing Flaws)
*   **Firebase Race Conditions:** AI originally planned to update the Score dynamically via local calculation. After a simulated code review, it corrected the approach by using `ServerValue.increment(1)` for atomic score updates.
*   **Bot RTDB Overload:** AI detected that running 6 concurrent bots using isolating would result in massive connection overloads to Firebase. It proactively implemented a **Jitter Logic** (random 1-4 second delays) in the `BotService` before claiming and solving to simulate human latency and queue distribution.
*   **Deterministic Regeneration:** AI identified an edge case where random number generation on the client during a solve leads to asymmetric towers between teams. It introduced the `towerPool` array logic, where clients safely increment a `poolIndex` using Firebase Transactions to extract pre-determined random numbers deterministically.

### 4. Advanced Fairness & Session Management (Refactoring Phase)
*   **Strict Matchmaking Rules:** AI designed and implemented the `JoinMatchResult` system to enforce "Wait-only" join policies, rejecting players from entering matches already in the `running` state.
*   **Ghost Player Cleanup:** Suggested a transactional cleanup of inactive players in the waiting lobby during session resets, maintaining accurate `teamCounts` and preventing "dead slots."
*   **Bot Simulation Guardrails:** Implemented an `_activeLoops` registry to prevent multiple concurrent logic cycles for the same bot if the simulation is toggled repeatedly.

### 5. Backend Health Monitoring
*   **Cloud Function Proactive Warning:** AI implemented a diagnostic detector in the `MatchController`. If the match timer hits zero and the status remains `running`, the UI triggers a "Backend Warning" snackbar to alert the developer that the Functions emulator or production backend is not responding.

## 3. Key Implementations Based on AI Suggestions
*   `BfsSolver.getOptimalMoves` executed inside `compute()`.
*   RTDB `runTransaction` explicitly scoped to `/teams/teamA/towers/towerId` instead of the parent `/teams/teamA` node.
*   **GetX State Sync with Flame Loop:** AI identified that standard Flutter builders drop frame states when continuously passed to Flame's `GameWidget`. It refactored `TeamArenaWidget` into a `StatefulWidget` to persist the `TowerChallengeGame` instance and explicitly call `syncTowers()` dynamically during the `GetBuilder` updates without losing internal Flame render states.
*   Deterministic `towerPool` generation with atomic index pointers.
*   `JoinMatchResult` formatted as a structured entity instead of string parsing.
*   Transactional decrement of `teamCounts` during debug session resets to ensure multiplayer lobby integrity.
*   `_activeLoops` set-based registry in `BotService` to ensure single-instance logic per bot UID.

### UI / UX Render Engine (Flame Migration)
*   **Flame Migration:** Replaced native standard Flutter Widgets (`Container`, `ListView`) with Flame's pipeline. Specifically, `TowerChallengeGame` was rewritten from a dual-camera setup to a `Single-Team` horizontal scrolling architecture. The `TowerComponent` now natively renders vector rectangles and leverages `TapCallbacks` instead of standard `GestureDetector` widgets to fulfill real game-engine interactive requirements.
