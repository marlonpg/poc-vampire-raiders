# Phase 1: Visual Architecture & Data Flow

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        VAMPIRE RAIDERS                          │
│                    Multiplayer System (Phase 1)                 │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ AUTOLOAD SINGLETON (Always Running)                              │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓    │
│  ┃        MultiplayerManager (multiplayer_manager.gd)   ┃    │
│  ┃                                                       ┃    │
│  ┃  ┌─ Network Initialization                           ┃    │
│  ┃  │  start_host() → ENetMultiplayerPeer.create_server ┃    │
│  ┃  │  join_game()  → ENetMultiplayerPeer.create_client ┃    │
│  ┃  │                                                    ┃    │
│  ┃  ├─ Player Management (Server Authority)             ┃    │
│  ┃  │  players_info: Dictionary                         ┃    │
│  ┃  │  ├─ player_id → {name, position, health, ...}     ┃    │
│  ┃  │  ├─ register_player()                             ┃    │
│  ┃  │  └─ unregister_player()                           ┃    │
│  ┃  │                                                    ┃    │
│  ┃  ├─ State Synchronization (RPC Based)                ┃    │
│  ┃  │  sync_player_position()      [Unreliable]         ┃    │
│  ┃  │  sync_player_stats()         [Unreliable]         ┃    │
│  ┃  │  notify_player_joined()      [Reliable]           ┃    │
│  ┃  │  send_full_game_state()      [Reliable]           ┃    │
│  ┃  │                                                    ┃    │
│  ┃  └─ Anti-Cheat Layer                                 ┃    │
│  ┃     _validate_movement()                             ┃    │
│  ┃     └─ Check: distance ≤ speed * delta * 1.1         ┃    │
│  ┃     _validate_stats()                                ┃    │
│  ┃     └─ Check: health, level, xp integrity            ┃    │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

                              ↓↓↓

┌──────────────────────────────────────────────────────────────────┐
│ MAIN SCENE: Lobby                                                │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Screen 1: Mode Selection                               │    │
│  │ ┌──────────────────────────────────────────────────┐   │    │
│  │ │ [Host Game] [Join Game]                          │   │    │
│  │ └──────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────┘    │
│           ↓ Host Clicked                ↓ Join Clicked         │
│  ┌─────────────────────────┐   ┌─────────────────────────┐     │
│  │ Host Setup Panel         │   │ Join Setup Panel       │     │
│  ├─────────────────────────┤   ├─────────────────────────┤     │
│  │ Player Name:            │   │ Server IP: 127.0.0.1    │     │
│  │ [____________] (default)│   │ Player Name:            │     │
│  │ [Start Server]          │   │ [____________]          │     │
│  └─────────────────────────┘   │ [Join Server]           │     │
│         ↓                       └─────────────────────────┘     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │         Lobby Panel (Both See This)                     │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │ Players:                                                 │   │
│  │ ┌────────────────────────────────────────────────────┐  │   │
│  │ │ Host - Lvl 1 Ready (HOST)                          │  │   │
│  │ │ Player 1 - Lvl 1 Not Ready                         │  │   │
│  │ │ Player 2 - Lvl 1 Not Ready                         │  │   │
│  │ └────────────────────────────────────────────────────┘  │   │
│  │ [Ready]                                    [Start Game]  │   │
│  │ (Host only sees Start button)                            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

                    [Start Game clicked by Host]
                              ↓↓↓

┌──────────────────────────────────────────────────────────────────┐
│ GAME SCENE: GameWorld                                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓   │
│  ┃ GameWorld (Node2D)                                   ┃   │
│  ┃ ┌────────────────────────────────────────────────┐   ┃   │
│  ┃ │ game_world.gd Script                           │   ┃   │
│  ┃ │ ├─ _spawn_all_players()                        │   ┃   │
│  ┃ │ │  └─ Reads players_info from MultiplayerMgr   │   ┃   │
│  ┃ │ ├─ _spawn_player(player_id, player_data)       │   ┃   │
│  ┃ │ │  ├─ Instantiate Player.tscn                  │   ┃   │
│  ┃ │ │  ├─ Set position from player_data            │   ┃   │
│  ┃ │ │  ├─ Set multiplayer_authority(player_id)     │   ┃   │
│  ┃ │ │  └─ add_child(player)                        │   ┃   │
│  ┃ │ └─ spawned_players: {player_id → player_node}  │   ┃   │
│  ┃ └────────────────────────────────────────────────┘   ┃   │
│  ┃                                                       ┃   │
│  ┃  ├─ Player Instances                                 ┃   │
│  ┃  │  ┌──────────────────────────┐                     ┃   │
│  ┃  │  │ Player 1 (Host)          │                     ┃   │
│  ┃  │  │ Authority: Host          │                     ┃   │
│  ┃  │  │ Position: (0, 0)         │                     ┃   │
│  ┃  │  │ is_local_player: true    │                     ┃   │
│  ┃  │  │ (MOVES with WASD)        │                     ┃   │
│  ┃  │  └──────────────────────────┘                     ┃   │
│  ┃  │       ↕ Synced via RPC                            ┃   │
│  ┃  │  ┌──────────────────────────┐                     ┃   │
│  ┃  │  │ Player 2 (Client)        │                     ┃   │
│  ┃  │  │ Authority: Client        │                     ┃   │
│  ┃  │  │ Position: (200, 0)       │                     ┃   │
│  ┃  │  │ is_local_player: false   │                     ┃   │
│  ┃  │  │ (Reads network updates)  │                     ┃   │
│  ┃  │  └──────────────────────────┘                     ┃   │
│  ┃  │                                                    ┃   │
│  ┃  └─ Enemies, Loot, Extraction Points (Shared)        ┃   │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Player Script Flow

```
Player.gd (CharacterBody2D)
│
├─ _ready()
│  ├─ Get multiplayer_authority() → player_id
│  ├─ is_local_player = is_multiplayer_authority()
│  └─ Initialize health, level, xp
│
├─ _physics_process(delta)
│  │
│  ├─ IF NOT is_local_player: RETURN
│  │
│  ├─ Get input (WASD)
│  ├─ Calculate velocity
│  ├─ move_and_slide()
│  │
│  ├─ position_sync_timer += delta
│  │
│  └─ IF position_sync_timer >= 0.1:
│     ├─ position_sync_timer = 0
│     ├─ IF position changed:
│     │  ├─ last_synced_position = position
│     │  └─ _sync_position_to_network()
│     │     └─ MultiplayerManager.update_player_position(position)
│     │        └─ RPC sync_player_position (UNRELIABLE)
│     └─ END IF
│
├─ add_xp(amount)
│  ├─ IF NOT is_local_player: RETURN
│  ├─ xp += amount
│  ├─ _check_level_up()
│  └─ _sync_stats_to_network()
│     └─ MultiplayerManager.update_player_stats(h, l, x)
│        └─ RPC sync_player_stats (UNRELIABLE)
│
└─ take_damage(amount)
   ├─ IF NOT is_local_player: RETURN
   ├─ health -= amount
   ├─ _sync_stats_to_network()
   └─ IF health <= 0: die()
      ├─ MultiplayerManager.on_player_died()
      │  └─ RPC handle_player_death (RELIABLE)
      └─ [Will drop loot in Phase 3]
```

---

## Network Message Flow: Player Movement Sync

```
TIME 0ms: Player 1 Moves
┌─────────────┐
│  CLIENT 1   │
│  (Host)     │
├─────────────┤
│ Input: W    │
│ Position:   │
│ (0,0) →     │
│ (0,-10)     │
│             │
│ position_   │
│ sync_timer  │
│ reaches     │
│ 0.1 sec     │
└─────────────┘
         ↓
         RPC: sync_player_position(1, (0,-10))
         MODE: UNRELIABLE (FAST)
              ↓
         ┌───────────────────────────┐
         │  SERVER (on Host)         │
         ├───────────────────────────┤
         │ Received from peer 1      │
         │ Position: (0, -10)        │
         │                           │
         │ _validate_movement():     │
         │ ├─ old_pos = (0, 0)       │
         │ ├─ new_pos = (0, -10)     │
         │ ├─ distance = 10 units    │
         │ ├─ max_allowed = 300 *    │
         │ │  0.016 * 1.1 = 5.28     │
         │ ├─ 10 > 5.28? YES        │
         │ │  → CHEAT DETECTED!      │
         │ └─ Reject update          │
         │                           │
         │ players_info[1].position  │
         │ remains (0, 0)            │
         └───────────────────────────┘
              ↓
         RPC: broadcast_player_position(1, (0,0))
         (Send corrected position to all)
              ↓↓↓
    ┌─────────────┐    ┌─────────────┐
    │  CLIENT 1   │    │  CLIENT 2   │
    │  (Host)     │    │  (Player)   │
    ├─────────────┤    ├─────────────┤
    │ Receive:    │    │ Receive:    │
    │ P1 at (0,0) │    │ P1 at (0,0) │
    │             │    │             │
    │ Draw sprite │    │ Draw sprite │
    │ at (0,0)    │    │ at (0,0)    │
    └─────────────┘    └─────────────┘
    Both see same truth!
```

---

## Authority Pattern Visualization

```
┌────────────────────────────────────────────────────────────┐
│              AUTHORITY PATTERN FLOW                        │
└────────────────────────────────────────────────────────────┘

SCENARIO 1: Legitimate Movement
═════════════════════════════════

CLIENT                          SERVER                 OTHER CLIENTS
  │                               │                        │
  ├─ Input: WASD                  │                        │
  ├─ Calculate: v=(0,-300)        │                        │
  ├─ move_and_slide()             │                        │
  ├─ pos = (0,-5)                 │                        │
  │                               │                        │
  └─→ RPC: sync_position(1, (0,-5))                       │
       [UNRELIABLE]               │                        │
                                  ├─ Validate             │
                                  │ ├─ old_pos = (0,0)    │
                                  │ ├─ delta = 5 units    │
                                  │ ├─ allowed = 5.28     │
                                  │ └─ VALID ✓            │
                                  │                        │
                                  ├─ Update: p1=(0,-5)    │
                                  │                        │
                                  └─→ RPC: broadcast_position
                                      (1, (0,-5))          │
                                      [UNRELIABLE]         │
                                                           ├─ Receive
                                                           ├─ p1=(0,-5)
                                                           ├─ Draw at
                                                           │  (0,-5)
                                                           └─ ✓

───────────────────────────────────────────────────────────

SCENARIO 2: Speed Hack Attempt
═══════════════════════════════

HACKER CLIENT                   SERVER                 OTHER CLIENTS
  │                               │                        │
  ├─ Fake: pos=(0,-500)           │                        │
  │ (Claims teleported 500 units)│                        │
  │                               │                        │
  └─→ RPC: sync_position(3, (0,-500))                     │
       [UNRELIABLE]               │                        │
                                  ├─ Validate             │
                                  │ ├─ old_pos = (0,0)    │
                                  │ ├─ delta = 500 units  │
                                  │ ├─ allowed = 5.28     │
                                  │ └─ INVALID ✗          │
                                  │                        │
                                  ├─ Log: "Cheater!"      │
                                  │ ├─ Ignore update      │
                                  │ ├─ Keep: p3=(0,0)     │
                                  │ └─ Optionally ban      │
                                  │                        │
                                  └─→ NO BROADCAST        │
                                      (Corrected pos       │
                                      already in     1     └─ See hacker
                                      players_info)          frozen at
                                                             (0,0)
                                                           └─ ✗ (fails)

───────────────────────────────────────────────────────────

SCENARIO 3: XP Injection
════════════════════════

HACKER CLIENT                   SERVER                 OTHER CLIENTS
  │                               │                        │
  ├─ Fake: xp=99999              │                        │
  │ (Claims max XP)              │                        │
  │                               │                        │
  └─→ RPC: sync_stats(2, h=100, l=50, x=99999)          │
       [UNRELIABLE]               │                        │
                                  ├─ Validate             │
                                  │ ├─ x < prev_x?        │
                                  │ ├─ 99999 > 1? YES     │
                                  │ ├─ level jumped?      │
                                  │ ├─ 50 > 1+1? YES      │
                                  │ └─ INVALID ✗          │
                                  │                        │
                                  ├─ Log: "XP hack!"      │
                                  │ ├─ Ignore update      │
                                  │ ├─ Keep: p2=old_stats │
                                  │ └─ Optional: kick      │
                                  │                        │
                                  └─ NO BROADCAST        │
                                                           └─ Player
                                                              stays at
                                                              level 1
                                                           └─ ✗ (fails)
```

---

## Data Structure: players_info Dictionary

```
players_info = {
    1: {                           # Player 1 (Host)
        "id": 1,
        "name": "Host",
        "is_host": true,
        "position": Vector2(0, 0),
        "health": 100,
        "max_health": 100,
        "level": 1,
        "xp": 0,
        "ready": true
    },
    2: {                           # Player 2 (Client)
        "id": 2,
        "name": "Player1",
        "is_host": false,
        "position": Vector2(200, 0),
        "health": 100,
        "max_health": 100,
        "level": 1,
        "xp": 0,
        "ready": true
    },
    3: {                           # Player 3 (Spectator or not ready)
        "id": 3,
        "name": "Player2",
        "is_host": false,
        "position": Vector2(0, 200),
        "health": 100,
        "max_health": 100,
        "level": 1,
        "xp": 0,
        "ready": false
    }
}

# Accessed via:
var player1_pos = players_info[1]["position"]
var all_positions = [players_info[i]["position"] for i in players_info.keys()]
```

---

## RPC Call Reference

| RPC Function | Direction | Mode | Purpose |
|---|---|---|---|
| `request_player_registration` | Client → Host | Reliable | Request to join |
| `notify_player_joined` | Host → All | Reliable | Announce new player |
| `send_full_game_state` | Host → Client | Reliable | Initial sync |
| `sync_player_position` | Client → Host | Unreliable | Position update |
| `broadcast_player_position` | Host → All | Unreliable | Corrected position |
| `sync_player_stats` | Client → Host | Unreliable | Stats update |
| `broadcast_player_stats` | Host → All | Unreliable | Corrected stats |
| `handle_player_death` | Any → Host | Reliable | Death notification |
| `set_player_ready` | Any → Host | Reliable | Ready toggle |
| `begin_game` | Host → All | Reliable | Game start signal |

---

## State Machine: Player Connection Lifecycle

```
START
  │
  ├─ MODE SELECTION ─────────┐
  │  [Host] [Join]           │
  │                           │
  ├─ IF HOST SELECTED        │
  │  ├─ HOST PANEL           │
  │  │ [Enter Name] [Start]  │
  │  │                       │
  │  └─→ start_host()        │
  │     ├─ Create Server     │
  │     ├─ Register self     │
  │     └─→ LOBBY_HOST       │
  │                           │
  └─ IF JOIN SELECTED        │
     ├─ JOIN PANEL           │
     │ [IP] [Name] [Join]    │
     │                       │
     └─→ join_game()         │
        ├─ Create Client     │
        ├─ Connect to IP     │
        └─→ CONNECTING       │
           (wait for server)  │
           ├─ ON SUCCESS     │
           └─→ LOBBY_CLIENT  │
           ├─ ON FAILURE     │
           └─→ ERROR         │
               [Retry]       │
                            │
        ┌──────────────────┬─┘
        │                  │
    LOBBY_HOST        LOBBY_CLIENT
    (Both same UI)
    │                  │
    ├─ Show players   ├─ Show players
    ├─ Ready button   ├─ Ready button
    ├─ Countdown      ├─ Countdown
    │                  │
    ├─ [Ready]        ├─ [Ready]
    │                  │
    ├─ IF HOST READY  ├─ IF PLAYER READY
    │  ├─ [Start]btn  │  │
    │  │  enabled     │  │
    │  └─ Host clicks │  │
    │     [Start]     │  │
    │                  │
    └─→ begin_game() RPC
        ├─ All clients
        │ receive signal
        └─→ GAME_ACTIVE
            (GameWorld loaded)
            ├─ Enemies spawn
            ├─ Players spawn
            ├─ Movement syncs
            └─ Game plays!
```

---

## Anti-Cheat Detection Examples

### Movement Hack Detection
```
Player reports: "I'm at (1000, 1000)"
Server knows: Last position was (100, 100)
Delta time: 16ms

Calculation:
- Distance traveled: sqrt((1000-100)² + (1000-100)²) = 1,273 units
- Max allowed: 300 units/sec * 0.016 sec * 1.1 = 5.28 units
- 1,273 > 5.28? YES → HACK DETECTED

Action: Rollback to (100, 100)
Log: "Speed hack attempt from player 2"
```

### Level-Up Hack Detection
```
Player reports: "I'm level 50, XP=50000"
Server knows: Last level was 5, XP was 100

Validation:
- XP decreased? 50000 < 100? NO
- Level increased by max 1? 50 > 5+1? YES → INVALID

Action: Ignore update, keep level 5, XP 100
Log: "Level injection from player 3"
```

### Stat Injection Detection
```
Player reports: "Health=9999, Max=100"
Server knows: Max health was 100

Validation:
- Health > max_health? 9999 > 100? YES → INVALID

Action: Ignore update, keep health at previous valid value
Log: "Health injection from player 1"
```

---

## Sync Intervals & Performance

```
┌──────────────────────────────────────────┐
│ Sync Interval Trade-offs                 │
└──────────────────────────────────────────┘

Faster Sync (50ms):
├─ Pros: Smoother movement, less desync
├─ Cons: More network traffic, higher CPU
└─ Use for: LAN, esports

Default (100ms):
├─ Pros: Good balance
├─ Cons: Slight delay visible
└─ Use for: Standard co-op

Slower (200ms):
├─ Pros: Low bandwidth, low CPU
├─ Cons: Noticeable delay
└─ Use for: Slow internet

Measurement:
- Messages/sec = 1 / position_sync_interval
- 100ms = 10 updates/sec per player
- 4 players = 40 updates/sec total
- Bandwidth: ~200 bytes/update = ~8 KB/sec
```

---

This completes Phase 1's visual architecture and data flows!
