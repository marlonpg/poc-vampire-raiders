# Known Issues

## 1. Player Inventory Not Cleared on Death (FIXED)
**Status**: Implementation attempted but reverted - needs careful retesting
**Description**: When a player dies, equipped items are not being cleared from the client UI.
**Server-Side**: `CombatSystem.java` - `dropAllItemsForPlayer()` correctly:
  - Drops all inventory items (both equipped and unequipped)
  - Unequips all slots (weapon, helmet, armor, boots)
  - Logs: `DEATH UNEQUIP: player=X, weapon=true, helmet=true, armor=true, boots=true`
**Client-Side**: Issue is that client doesn't refresh inventory display after respawning
- World scene needs to request fresh inventory after respawn
- Attempted fix: Call `net_manager.request_inventory()` in `_process()` or after player joins
- Problem: Caused duplicate player spawning and camera tracking issues
- Root cause: Player was being spawned twice - once in `_join_as_player()` and once in `_update_players()`
**Solution To Try**:
  1. Remove local player spawn from `_join_as_player()` - let server's game state create it
  2. Request inventory safely in `_process()` after `player_instance != null` (use a one-time flag)
  3. Reset the flag when scene reloads (respawn)
  4. Test carefully - ensure no duplicate players spawn

## 2. UDP Health Fallback (COMPLETED)
**Status**: Implemented and working
**Description**: When UDP fails repeatedly, client automatically falls back to TCP-only
**Implementation**: `udp_network_client.gd`
  - Tracks failure count with `udp_failures` counter
  - Disables UDP after 6 failures (`UDP_FAIL_THRESHOLD`)
  - Resets failures on successful sends
  - Gates registration/sends to fall back to TCP when disabled
  - Logs errors: `[UDP_FACADE] UDP error X/6: <reason>`

## 3. Equipped Item Query Bug (IDENTIFIED)
**Status**: Identified but not yet fixed
**File**: `EquippedItemRepository.java` - `getEquippedItems()`
**Problem**: Current query uses LEFT JOIN with OR condition on all slots:
```java
"LEFT JOIN inventory inv ON (e.weapon = inv.id OR e.helmet = inv.id OR e.armor = inv.id OR e.boots = inv.id)"
```
**Issue**: This creates a Cartesian product when multiple items are equipped, causing:
- Duplicate result rows
- Unable to determine which slot each item belongs to
**Solution**: Use UNION to fetch each slot separately:
```java
SELECT 'weapon' as slot_type, e.weapon as inv_id, ... FROM equipped_items e LEFT JOIN inventory inv ON e.weapon = inv.id WHERE e.player_id = ? AND e.weapon IS NOT NULL
UNION ALL
SELECT 'helmet' as slot_type, e.helmet as inv_id, ... FROM equipped_items e LEFT JOIN inventory inv ON e.helmet = inv.id WHERE e.player_id = ? AND e.helmet IS NOT NULL
UNION ALL
SELECT 'armor' as slot_type, e.armor as inv_id, ... FROM equipped_items e LEFT JOIN inventory inv ON e.armor = inv.id WHERE e.player_id = ? AND e.armor IS NOT NULL
UNION ALL
SELECT 'boots' as slot_type, e.boots as inv_id, ... FROM equipped_items e LEFT JOIN inventory inv ON e.boots = inv.id WHERE e.player_id = ? AND e.boots IS NOT NULL
```

## 4. Old Client Sessions with Stale Tokens
**Status**: Not a bug - user error
**Description**: Old Godot client instances still running after server restart cause "invalid token" UDP errors
**Solution**: Kill all old client processes before testing new server version
