# Realtime Tower Mini-Game 🏰

A **Flutter multiplayer mini-game** for Android/iOS using Flame Engine + Firebase Realtime Database.

## 📱 Setup & Run

### 1. Prerequisites
- Flutter SDK ≥ 3.19
- Android emulator or physical device (API 21+)
- Firebase project with Realtime Database enabled

### 2. Firebase Configuration
1. Create a Firebase project at https://console.firebase.google.com
2. Enable **Realtime Database** (Start in test mode or apply `database.rules.json`)
3. Register an Android app with package name `com.teamgame.minitower.mini_tower_game`
4. Download `google-services.json` → place in `android/app/`
5. The `lib/firebase_options.dart` already contains dummy keys — replace with your project's values via:
   ```
   flutterfire configure
   ```

### 3. Run the App
```bash
flutter pub get
flutter run
```

---

## 🎮 How to Play

### Starting a Match
1. Launch the app → enter your name → tap **Join / Create Match**
2. Share your device or start with bots:
   - Tap the **🤖 (bot icon)** in the top-right of the Match screen
   - Add 1–6 bots, assign to a team, then hit **▶ Start Simulation**
3. Tap **⚡ Force Start** to begin without waiting for 8 players

### Playing
- **Tap an available tower** (yellow `+` button) to claim it
- The **Tower Attempt Overlay** opens:
  - Press `+10` to add 10 or `×2` to multiply by 2
  - Goal: reach the **Target value** exactly
  - Press `↻ Restart` to reset without losing your claim
  - Press `< Back` to cancel (releases the tower)
- **Win:** The team with the **most solved towers** when the 5-minute timer runs out wins

---

## 🏗️ Architecture

### Clean Architecture Layers
```
lib/
├── core/                    # DI bindings, constants
├── features/
│   └── match/
│       ├── data/            # Firebase repository implementation
│       ├── domain/          # Entities, use cases, BFS solver
│       └── presentation/
│           ├── controllers/ # GetX state management
│           ├── flame/       # Flame Engine components
│           ├── pages/       # Match page, Lobby screen
│           └── widgets/     # Team arena, tower modal, overlays
```

### Key Components

| Component | File | Responsibility |
|---|---|---|
| `TowerChallengeGame` | `flame/tower_challenge_game.dart` | Flame game loop, camera, tower rendering |
| `TowerComponent` | `flame/tower_component.dart` | Individual tower Flame component with TapCallbacks |
| `MatchController` | `controllers/match_controller.dart` | GetX controller: AFK detection, timers, state |
| `MatchRepositoryImpl` | `data/repositories/match_repository_impl.dart` | All Firebase RTDB transactions |
| `BfsSolver` | `domain/usecases/bfs_solver.dart` | BFS optimal solver (runs in background isolate) |
| `BotService` | `domain/usecases/bot_service.dart` | Bot simulation with jitter & optimal solving |

### Firebase RTDB Structure
```
/matches/{matchId}
  /meta:  { status, targetValue, towerPool, poolIndexA, poolIndexB, startAt, endAt, hostUid }
  /teams
    /teamA:  { score, towers: { tower_0..tower_N: { startValue, state, claimedBy, claimExpiresAt, solvedBy, movesTaken, optimalMoves } } }
    /teamB:  (same)
  /players
    /{uid}: { displayName, team, lastSeenAt, stats: { towersSolved, totalMoves } }
/system/waiting_match: {matchId}  ← atomic queue for lobby
```

### RTDB Transactions Used
- **Join/Create** — atomic team-count increment to prevent race conditions
- **Claim tower** — validates `state == available` OR expired claim, sets 15s expiry
- **Solve tower** — validates `claimedBy == uid`, atomically marks solved
- **Score increment** — `ServerValue.increment(1)` for atomic score update
- **Pool index** — atomic increment for deterministic tower generation
- **End match** — jittered transaction so only 1 of 8 clients actually writes `ended`

---

## 🤖 AFK Detection
- Heartbeat written to RTDB every **5 seconds**
- Player considered AFK after **30 seconds** of no heartbeat
- Claimed towers are auto-released after **15 seconds** (with jitter to prevent stampede)
- AFK players shown with 🔴 badge + strikethrough in player roster

---

## 🧮 BFS Solver
The optimal move solver uses **Breadth-First Search** over the integer graph:
- Nodes: integer values 0..200,000
- Edges: `+10` and `×2` operations
- Output: minimum steps from `startValue` to `targetValue` (or -1 if unreachable)
- Runs in a **background Dart isolate** via `compute()` to avoid UI jank

---

## 🔐 Security Rules
See `database.rules.json`:
- Users can only set `claimedBy`/`solvedBy` to their own UID (for their team only)
- Score can only increase by 1 at a time
- Pool index can only increase monotonically
