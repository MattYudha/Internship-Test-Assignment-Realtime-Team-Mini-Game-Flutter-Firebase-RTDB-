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

## 3. Key Implementations Based on AI Suggestions
*   `BfsSolver.getOptimalMoves` executed inside `compute()`.
*   RTDB `runTransaction` explicitly scoped to `/teams/teamA/towers/towerId` instead of the parent `/teams/teamA` node.
*   GetX `MatchController` utilizing internal proactive `Timer.periodic` to reactively free up "Claimed" visually expired towers on the frontend instantly (AFK Management) without waiting for server triggers.
