# Vampire Raiders - Multiplayer Implementation Plan

## Architecture Overview: Server-Authoritative Host/Join

### Core Principle
**Server is the source of truth.** All state changes validated server-side to prevent cheating.

---

## Network Architecture

### Host/Join System
- **Host:** Player 1 creates a game session → becomes temporary server
- **Join:** Player 2-4 connect to host via P2P or relay
- **Authority:** Host validates all game state changes

### Authority Responsibilities
1. **Combat validation**
   - Verify damage calculations
   - Prevent speed hacks (check movement deltas vs time)
   - Validate level-ups and weapon selections

2. **Inventory/Loot validation**
   - Prevent item duplication
   - Verify item pickup is legitimate
   - Validate item drops on death

3. **Extraction validation**
   - Only extracted loot counts
   - Verify player reached extraction point
   - Confirm loot secured before countdown ends

4. **Anti-cheat checks**
   - Teleportation detection (position jumps)
   - Movement speed validation
   - Level/XP injection detection
   - Stat modification detection

---

## Implementation Phases

### Phase 1: Foundation (3-5 days)
- [ ] Set up Godot multiplayer nodes (MultiplayerSpawner, MultiplayerSynchronizer)
- [ ] Host/join lobby system
- [ ] Player connection/disconnection handling
- [ ] Basic state synchronization

### Phase 2: Authority & Validation (2-3 days)
- [ ] Movement validation (server checks position deltas)
- [ ] Combat validation (damage calculations on server)
- [ ] Level-up validation (XP on server, not client)
- [ ] Anti-cheat framework

### Phase 3: Loot & Inventory (2-3 days)
- [ ] Server-side inventory state
- [ ] Loot drop validation
- [ ] Pickup radius sync
- [ ] Death → drop all items

### Phase 4: PvP Mechanics (2-3 days)
- [ ] Dropped loot ownership tracking
- [ ] Loot stealing on proximity
- [ ] Enemy luring (player positions broadcast to all)
- [ ] PvP flags/timers

### Phase 5: Testing & Polish (1-2 days)
- [ ] Latency handling
- [ ] Disconnection recovery
- [ ] Rollback/resync scenarios

---

## Technical Implementation Details

### 1. Player Synchronization

**Server-Side State (Host Authority)**
```gdscript
# On host/server only
var players_state = {
    "player_1": {
        "position": Vector2,
        "level": int,
        "xp": int,
        "health": int,
        "inventory": [],
        "equipped_weapon": String,
        "is_alive": bool
    }
}
```

**Client → Server Validation**
- Client sends: `position`, `input_direction`
- Server validates: Movement speed legitimate? (delta_pos ≤ speed × delta_time)
- Server corrects: Broadcasts corrected position to all clients
- Anti-cheat: Flag suspicious movement patterns

### 2. Loot System with Anti-Dupe Protection

**Item ID System**
```gdscript
# Every loot item gets unique ID
var loot_item = {
    "id": unique_id,           # UUID - prevents duplication
    "type": "blood_vial",
    "owner_id": player_id,     # Who dropped it
    "position": Vector2,
    "claimed_by": null,        # null or player_id if stolen
    "claimed_time": 0          # When it was taken
}
```

**Drop on Death Flow**
1. Client signals death to server
2. Server validates death (health ≤ 0)
3. Server drops ALL inventory items with owner_id
4. Server broadcasts new loot positions
5. Server sets `claimed_by: null`
6. Clients see dropped items on ground

**Anti-Dupe Checks**
- Server maintains single source inventory per player
- All pickups verified on server before adding to inventory
- Clients only display what server sends
- Rollback mechanism if client receives invalid state

### 3. Death & Loot Stealing Mechanics

**When Player Dies:**
```
1. Server receives death signal
2. Server validates: is_alive == true, health == 0
3. Server iterates inventory, creates loot items
4. Server sets all items: owner_id = dead_player_id, claimed_by = null
5. Server broadcasts loot positions to all players
6. Respawn timer starts (10-15 seconds)
7. Dead player camera follows teammate or watches extraction
```

**Loot Stealing:**
```
1. Living player moves within pickup radius of dropped loot
2. Client sends pickup request
3. Server validates:
   - Distance ≤ pickup_radius
   - Player inventory has space
   - Item not already claimed
4. Server adds to inventory, sets claimed_by = player_id
5. Server broadcasts inventory update
6. Removed loot from ground for all clients
```

**Contested Loot (Multiple Nearby):**
```
- First valid pickup request wins
- Server processes in order (latency-sorted)
- Other requests fail: "Item already claimed"
```

### 4. Anti-Cheat Validation Layer

**Client → Server Communication Pattern**

```gdscript
# WRONG - Client sends final state
client_sends("level_up", {"new_level": 50})

# RIGHT - Client sends action, server validates
client_sends("claim_level_up", {"passive_choice": "move_speed"})
server_validates:
  - player.xp >= xp_threshold_for_level
  - player.level < 50  # Can't skip levels
  - passive_choice exists in reward_pool
server_executes:
  - player.level += 1
  - player.xp -= xp_threshold
  - player.passives.append(passive_choice)
server_broadcasts new state
```

**Key Anti-Cheat Rules**
1. **Never trust client position** → Always validate deltas
2. **Never trust client stats** → Calculate on server
3. **Never trust client inventory** → All pickups verified
4. **Never trust client time** → Use server time for cooldowns
5. **Duplicate item detection** → Check unique IDs on server

### 5. Extraction with Anti-Cheat

**Extraction Validation:**
```gdscript
# When player enters extraction zone
1. Server checks: player_inventory exists
2. Server creates immutable record of items
3. Countdown starts (10 seconds)
4. During countdown:
   - Server tracks player.position continuously
   - If player leaves zone → extraction cancelled
   - If player dies → loot drops (even during extraction!)
5. On success:
   - Server removes items from world (consumed)
   - Server records extraction (for meta progression)
   - Server broadcasts: "Player extracted X items"
```

---

## Networking Implementation (Godot)

### Using Godot's MultiplayerAPI

**Host/Join Setup:**
```gdscript
# Host creates peer
var peer = ENetMultiplayerPeer.new()
peer.create_server(PORT, MAX_CLIENTS)
multiplayer.multiplayer_peer = peer

# Join connects to host
var peer = ENetMultiplayerPeer.new()
peer.create_client(HOST_IP, PORT)
multiplayer.multiplayer_peer = peer
```

**Player Spawning (Server Authority):**
```gdscript
@rpc("authority", "call_remote", "reliable")
func spawn_player(player_id: int, position: Vector2):
    var player = PLAYER_SCENE.instantiate()
    player.set_multiplayer_authority(player_id)
    add_child(player)
    player.position = position
```

**State Synchronization:**
```gdscript
@export var position: Vector2:
    set(value):
        # Client sends input
        if is_multiplayer_authority():
            position = value
            rpc("update_position", position)
    
    get:
        return position

@rpc("any_peer", "call_remote", "reliable")
func update_position(new_pos: Vector2):
    # Server validates and broadcasts
    if multiplayer.is_server():
        if validate_movement(new_pos):
            position = new_pos
            rpc("set_position", new_pos)  # Broadcast to all
```

---

## Latency & Desync Handling

### Client-Side Prediction
- Clients show immediate feedback (smooth movement)
- Server validates asynchronously
- Rollback if validation fails

### Loot Race Conditions
- Multiple players reach loot simultaneously
- Server picks first valid request (network order)
- Losers get "Item already taken" message
- Prevents frustration

### Position Correction
- Client predicts position ahead of time
- Server sends correction if prediction wrong
- Lerp correction over ~100ms
- Prevents teleporting jank

---

## Death Flow (Complete Example)

```
Player 1 has: [Blood Vial, Relic Shard, Ancient Rune]
Player 2 nearby, watching

[Player 1 takes lethal damage]
→ Client: player.health = 0
→ Client sends: rpc("death", player_id)

[Server receives death]
→ Server validates: player_state[1].is_alive == true
→ Server creates loot items:
   • Loot_ID_001: Blood Vial @ player_pos, owner=1
   • Loot_ID_002: Relic Shard @ player_pos, owner=1
   • Loot_ID_003: Ancient Rune @ player_pos, owner=1
→ Server sets all: claimed_by = null
→ Server broadcasts: "Player 1 died, loot dropped"

[Player 2 sees loot on screen]
→ Player 2 moves to pickup radius
→ Client sends: pickup_request(Loot_ID_001)

[Server validates pickup]
→ Server checks: distance_valid && inventory_space && not_claimed
→ Server: Player 2 inventory.append(Blood Vial)
→ Server broadcasts: Loot_ID_001 removed from ground
→ Server: Player 2 inventory update

[Result] Player 2 stole Player 1's loot!
```

---

## Implementation Roadmap

### Week 1
- [ ] Day 1-2: Godot multiplayer setup, host/join lobby
- [ ] Day 3: Player spawning and basic sync
- [ ] Day 4-5: Movement validation + anti-cheat framework

### Week 2
- [ ] Day 1-2: Server-side inventory system
- [ ] Day 3: Death → loot drop mechanics
- [ ] Day 4: Loot stealing + pickup validation
- [ ] Day 5: Testing + bug fixes

### Week 3 (Optional Polish)
- [ ] Disconnection recovery
- [ ] Respawn mechanics
- [ ] Extraction validation
- [ ] Performance optimization

---

## Security Checklist

- [ ] All player stats calculated server-side
- [ ] Position deltas validated for speed hacks
- [ ] Inventory unique IDs prevent duplication
- [ ] Level-up XP threshold checked server-side
- [ ] Weapon selections verified against unlocks
- [ ] Extraction items immutable on server
- [ ] No client-sent state accepted as truth
- [ ] Suspicious behavior logged/flagged
- [ ] Rollback system for desyncs

---

## Testing Strategy

1. **Single Player + AI Host** (easiest)
   - Test mechanics work over network

2. **Local Network** (LAN)
   - 2-4 players on same network
   - Test latency handling

3. **Over Internet**
   - Use relay (later) or port forwarding
   - Stress test with intentional lag

4. **Cheating Attempts**
   - Try to teleport (position hack)
   - Try to inject level (XP hack)
   - Try to dupe items (pickup spam)
   - Try to steal claimed loot

---

## Next Steps

1. **Start with Phase 1:** Set up host/join + basic player sync
2. **Add Phase 2:** Movement validation + anti-cheat core
3. **Implement Phase 3:** Server-side inventory + drop mechanics
4. **Test thoroughly:** Especially loot sync and death flows

Ready to begin implementation?
