# Vampire Raiders - Multiplayer Quick Start

## 🎮 Testing Local Co-op (Phase 1)

### Prerequisites
- Godot 4.5+
- Two instances of the game running

### Step 1: Start Host Instance
1. Open Godot editor
2. Press `F5` (Run)
3. Click **"Host Game"**
4. Enter a player name (or leave default)
5. Click **"Start Server"**

✅ You should see the lobby panel with your player listed as HOST

### Step 2: Start Client Instance
1. Open a **second** Godot window (File → New Window)
2. Press `F5` (Run)
3. Click **"Join Game"**
4. IP field is pre-filled with `127.0.0.1` (localhost)
5. Enter a different player name
6. Click **"Join Server"**

✅ You should see both players in the lobby now

### Step 3: Start Game
1. **Host:** Click **"Ready"**
2. **Client:** Click **"Ready"**
3. **Host:** Click **"Start Game"**

✅ Both players should load into GameWorld scene
✅ You should see your player (red icon) and teammate's player

### Step 4: Test Movement
- **WASD** or **Arrow Keys** to move
- Each player should move independently
- Both players see each other moving in real-time

---

## ✅ What to Check

### Player Spawning
- [ ] Host spawns at position (0, 0)
- [ ] Client spawns at position (200, 0)
- [ ] Each player is a separate sprite

### Movement Sync
- [ ] Pressing WASD moves your character
- [ ] Other player moves on their client too
- [ ] Position updates smoothly (every 100ms)

### Network Authority
- [ ] Only **your** player responds to your input
- [ ] You **cannot** control the other player
- [ ] Server validates all movement (anti-cheat working)

---

## 🔍 Debug Tips

### View Network Activity
Add this to MultiplayerManager to see all RPC calls:

```gdscript
func _process(_delta):
    # In _ready or _process
    if multiplayer.is_server():
        print("Players connected: ", players_info.size())
```

### Check Player Authority
In player.gd _ready():
```gdscript
print("Player ID: ", player_id)
print("Is local: ", is_local_player)
print("Authority: ", get_multiplayer_authority())
```

### View Console Output
- Godot opens `Output` panel automatically
- Watch for "Player registered", "Peer connected", etc.

---

## 🚀 Common Issues & Fixes

### "Join fails - Connection refused"
**Problem:** Can't find server
**Solution:** 
- Make sure Host is running first
- Check IP is `127.0.0.1`
- Check port 7777 isn't blocked
- Try restarting Godot

### "Players see different positions"
**Problem:** Lag/latency
**Solution:**
- This is normal! Positions sync every 100ms
- On LAN (same machine), should be <10ms delay
- Over internet, expect 50-200ms delay

### "Movement frozen / no response"
**Problem:** Input not working
**Solution:**
- Make sure you're in GameWorld (not lobby)
- Check that `is_local_player = true`
- Try pressing WASD slowly

### "Only one player spawned"
**Problem:** Client didn't connect
**Solution:**
- Check console for error messages
- Make sure Host is ready before Client joins
- Verify both have same lobby.gd script

---

## 📊 Network Flow (What's Happening)

```
┌─────────────┐                ┌─────────────┐
│   Client 1  │                │   Client 2  │
│   (Host)    │                │   (Player)  │
└─────────────┘                └─────────────┘
      ↓                              ↓
   Input: WASD                   Input: WASD
      ↓                              ↓
   Local Move                     Local Move
   [0, 300]                       [200, 300]
      ↓                              ↓
   RPC: sync_player_position      RPC: sync_player_position
      ↓────────────────────────────→↓
                Server validates
                Movement OK? ✓
                Broadcast to all
      ↓←────────────────────────────↓
   Receive: [200, 300]        Receive: [0, 300]
      ↓                              ↓
   Draw Client 2 at [200, 300] Draw Client 1 at [0, 300]
```

---

## 🎯 Next Phase Goals

After testing Phase 1:

1. **Phase 2: Combat Validation**
   - Add enemy spawning to multiplayer
   - Validate damage calculations
   - Test level-up system

2. **Phase 3: Loot System**
   - Drop items on death
   - Steal loot from other players
   - Unique item IDs to prevent duplication

3. **Phase 4: PvP Extraction**
   - Contest extraction points
   - Enemy luring mechanics
   - Extraction countdown

---

## 📝 Performance Notes

### Sync Interval (Current: 100ms)
- Faster = More responsive but higher bandwidth
- Slower = Less responsive but lower bandwidth
- Good default for LAN: **100ms (10 updates/sec)**
- Good for internet: **200ms (5 updates/sec)**

### Adjust in player.gd:
```gdscript
@export var position_sync_interval: float = 0.1  # Change this value
```

### Anti-Cheat Sensitivity (Current: 10% tolerance)
- Looser = Allow more lag compensation
- Stricter = Catch more cheaters
- Good default: **10% tolerance**

### Adjust in multiplayer_manager.gd:
```gdscript
max_allowed_distance = max_speed * delta_time * 1.1  # Change 1.1 to adjust
```

---

## 🎓 Learn More

- **How Godot Multiplayer Works:** [Godot Docs - MultiplayerAPI](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- **RPC Calls:** [Remote Procedure Calls](https://docs.godotengine.org/en/stable/tutorials/networking/using_rpc.html)
- **ENet Protocol:** [Godot ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)

---

## ✨ Ready to Test?

1. Save all files
2. Open Godot
3. Press `F5` to run
4. Follow steps 1-4 above
5. **Have fun!** 🎮

Report any issues or let me know what you'd like to improve!
