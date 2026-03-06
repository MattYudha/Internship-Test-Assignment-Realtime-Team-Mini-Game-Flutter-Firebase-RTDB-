# Realtime Team Mini-Game

A Flutter multiplayer mini-game simulating a realtime competitive tower-solving challenge. 

## Features
- **Clean Architecture & GetX:** Strict separation of UI, Domain, and Data logic.
- **Firebase Realtime Database:** Synchronized 8-player states using Transactions and Atomic Increments.
- **Deterministic Symmetry:** Both teams receive identical randomized towers through a synchronized `poolIndex` referencing a `towerPool`.
- **AFK & UX Management:** Proactive visual claims clearing when users AFK.
- **Bot Simulation:** Isolated BFS computation and jitter transactions to simulate real human load.

## Setup Instructions

### 1. Flutter Dependencies
Ensure you have the Flutter SDK installed.
Run the following in the project root:
```bash
flutter pub get
```

### 2. Firebase Configuration
Due to security reasons, you must connect this project to your own Firebase instance.
1. Create a Firebase Project.
2. Enable Realtime Database and Anonymous Authentication.
3. Install FlutterFire CLI if you haven't: `dart pub global activate flutterfire_cli`.
4. Run standard configuration: 
```bash
flutterfire configure --project=YOUR-PROJECT-ID
```
5. Replace the mock `lib/firebase_options.dart` that was generated.

### 3. Run
```bash
flutter run
```

## Architecture Notes
- **Transactions:** Claiming and Solving towers strictly target the leaf nodes (`/towers/<id>`) to prevent mass transaction collisions among 8 players.
- **Scoring:** Updating the team score uses `ServerValue.increment(1)` atomically. It does not use transactions to completely remove race conditions.
- **Tower Regeneration:** When a tower is solved, a transaction increments the `poolIndex` directly on the server to retrieve an identical new puzzle value from `towerPool` deterministically for both teams. 
- **BFS Threading:** `Isolate.run()` prevents the `0->200,000` depth algorithm from locking the main UI thread.
