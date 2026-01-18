package com.vampireraiders.systems;

import com.vampireraiders.database.EquippedItemRepository;
import com.vampireraiders.database.InventoryRepository;
import com.vampireraiders.database.WorldItemRepository;
import com.vampireraiders.game.Enemy;
import com.vampireraiders.game.GameState;
import com.vampireraiders.game.Player;
import com.vampireraiders.game.Tilemap;
import com.vampireraiders.game.WorldItem;
import com.vampireraiders.systems.ItemDropService;
import com.vampireraiders.util.Logger;

import java.util.Map;
import java.util.Random;

public class CombatSystem {
    private static final float COLLISION_DISTANCE = 40f;
    // Telegraph hitbox dimensions (width side-to-side, depth forward from enemy)
    private static final float TELEGRAPH_WIDTH = 96f;
    private static final float TELEGRAPH_DEPTH = 48f;
    private final ItemDropService itemDropService = new ItemDropService();
    private StateSync stateSync;

    public CombatSystem() {
        this.stateSync = null;
    }

    public void setStateSync(StateSync stateSync) {
        this.stateSync = stateSync;
    }

    public void update(String mapId, GameState state, float deltaTime) {
        checkPlayerEnemyCollisions(state);
    }

    private void checkPlayerEnemyCollisions(GameState state) {
        for (Player player : state.getAllPlayers().values()) {
            if (!player.isAlive()) continue;

            for (Enemy enemy : state.getAllEnemies()) {
                if (!enemy.isAlive()) continue;

                float distance = calculateDistance(player.getX(), player.getY(), 
                                                 enemy.getX(), enemy.getY());

                // Skip damage if player is inside safe zone
                if (com.vampireraiders.game.GameWorld.isInSafeZone(player.getX(), player.getY())) {
                    // Only cancel attack if not already telegraphing (let telegraph complete)
                    if (enemy.getAttackState() != Enemy.AttackState.TELEGRAPHING) {
                        enemy.endAttack();
                    }
                    continue;
                }
                
                // If enemy is telegraphing, check if it's time to apply damage
                if (enemy.isTelegraphExpired()) {
                    // Oriented rectangle hitbox in enemy forward direction
                    float dirX = enemy.getTelegraphTargetX() - enemy.getX();
                    float dirY = enemy.getTelegraphTargetY() - enemy.getY();
                    float len = (float) Math.sqrt(dirX * dirX + dirY * dirY);
                    if (len == 0) {
                        dirX = 1;
                        dirY = 0;
                        len = 1;
                    }
                    dirX /= len;
                    dirY /= len;
                    // Perpendicular vector
                    float perpX = -dirY;
                    float perpY = dirX;

                    float relX = player.getX() - enemy.getX();
                    float relY = player.getY() - enemy.getY();

                    float forward = relX * dirX + relY * dirY;       // projection on forward
                    float side = relX * perpX + relY * perpY;         // projection on side

                    boolean inside = forward >= 0 && forward <= TELEGRAPH_DEPTH && Math.abs(side) <= TELEGRAPH_WIDTH / 2f;

                    if (inside) {
                        // Apply damage
                        int enemyDamage = enemy.getDamage();
                        int playerDefense = calculatePlayerDefense(player);
                        int effectiveDamage = Math.max(1, enemyDamage - playerDefense);
                        player.takeDamage(effectiveDamage);
                        Logger.info("Player " + player.getUsername() + " took " + effectiveDamage + " damage from telegraph attack (base: " + enemyDamage + ", defense: " + playerDefense + ")");

                        // Broadcast damage event for client-side visual feedback
                        if (stateSync != null) {
                            stateSync.broadcastDamageEvent(player.getCurrentMapId(), player.getPeerId(), "player", effectiveDamage, player.getX(), player.getY());
                        }

                        if (!player.isAlive()) {
                            Logger.info("Player " + player.getUsername() + " died");
                            // On death: drop all equipped + inventory items to the world
                            dropAllItemsForPlayer(state, player);
                            // Respawn at safe zone center (get tilemap from GameWorld)
                            respawnPlayer(player, com.vampireraiders.game.GameWorld.getTilemap());
                        }
                    }
                    enemy.endAttack();  // Reset to IDLE for next attack
                }

                if (distance < COLLISION_DISTANCE) {
                    // Start telegraph when player gets close
                    if (enemy.getAttackState() == Enemy.AttackState.IDLE) {
                        enemy.startTelegraph(player.getX(), player.getY());
                    }
                } else {
                    // Out of range - don't cancel if already telegraphing (let it complete)
                    if (enemy.getAttackState() == Enemy.AttackState.IDLE) {
                        // Nothing to cancel
                    }
                    // If TELEGRAPHING, let it finish naturally
                }
            }
        }
    }

    public void damageEnemy(Enemy enemy, int damage, GameState state) {
        if (!enemy.isAlive()) return;

        enemy.takeDamage(damage);
        Logger.debug("Enemy " + enemy.getId() + " took " + damage + " damage");

        if (!enemy.isAlive()) {
            Logger.info("[FREEZE_DEBUG] Enemy " + enemy.getId() + " died, starting death sequence");
            
            enemy.die();  // Mark death time for respawn
            Logger.info("[FREEZE_DEBUG] Enemy death time marked");
            
            Logger.info("[FREEZE_DEBUG] About to remove enemy from active list");
            state.removeEnemy(enemy);  // Remove from active list immediately
            Logger.info("[FREEZE_DEBUG] Enemy removed from active list");
            
            Logger.info("[FREEZE_DEBUG] About to add enemy to respawn queue");
            state.addDeadEnemy(enemy);  // Add to respawn queue
            Logger.info("[FREEZE_DEBUG] Enemy added to respawn queue");
            
            Logger.info("[FREEZE_DEBUG] About to call rewardKiller");
            rewardKiller(state, enemy);
            Logger.info("[FREEZE_DEBUG] rewardKiller complete, death sequence finished");
        }
    }
    
    /**
     * Respawn a player at the safe zone center with full health
     */
    public void respawnPlayer(Player player, Tilemap tilemap) {
        // Teleport to safe zone center
        float[] center = tilemap.getSafeZoneCenter();
        player.setPosition(center[0], center[1]);
        
        // Reset health to full
        player.setHealth(player.getMaxHealth());
        
        // Clear velocity
        player.setInputDirection(0, 0);
        
        Logger.info("Player " + player.getUsername() + " respawned at safe zone center");
    }

    private void rewardKiller(GameState state, Enemy enemy) {
        int xpReward = enemy.getRewardXP();
        
        // Find nearest player to reward
        Player nearestPlayer = null;
        float closestDistance = Float.MAX_VALUE;

        for (Player player : state.getAllPlayers().values()) {
            if (!player.isAlive()) continue;

            float distance = calculateDistance(player.getX(), player.getY(),
                                             enemy.getX(), enemy.getY());
            if (distance < closestDistance) {
                closestDistance = distance;
                nearestPlayer = player;
            }
        }

        if (nearestPlayer != null && closestDistance < 500f) {
            nearestPlayer.gainXP(xpReward);
            Logger.info("Player " + nearestPlayer.getUsername() + " gained " + xpReward + " XP from enemy kill (type: " + enemy.getTemplateName() + "). Total XP: " + nearestPlayer.getXP() + ", Level: " + nearestPlayer.getLevel());
        } else {
            Logger.debug("Enemy " + enemy.getId() + " defeated but no player nearby to reward XP");
        }

        // Drop item asynchronously to avoid blocking game loop
        new Thread(() -> {
            try {
                WorldItem dropped = itemDropService.dropFromEnemy(enemy.getTemplateId(), enemy.getX(), enemy.getY());
                if (dropped != null) {
                    state.addWorldItem(dropped);
                    Logger.info("Dropped world item id=" + dropped.getId() + " template=" + dropped.getItemTemplateId() + " at (" + dropped.getX() + "," + dropped.getY() + ")");
                }
            } catch (Exception e) {
                Logger.error("Error dropping item from enemy " + enemy.getId(), e);
            }
        }).start();
    }

    private float calculateDistance(float x1, float y1, float x2, float y2) {
        float dx = x1 - x2;
        float dy = y1 - y2;
        return (float) Math.sqrt(dx * dx + dy * dy);
    }

    private int calculatePlayerDefense(Player player) {
        int playerId = player.getDatabaseId() > 0 ? player.getDatabaseId() : player.getPeerId();
        Map<String, Map<String, Object>> equipped = EquippedItemRepository.getEquippedItems(playerId);
        
        int totalDefense = 0;
        
        // Add armor defense
        Map<String, Object> armor = equipped.get("armor");
        if (armor != null && armor.get("defense") instanceof Number) {
            totalDefense += ((Number) armor.get("defense")).intValue();
        }
        
        // Add helmet defense
        Map<String, Object> helmet = equipped.get("helmet");
        if (helmet != null && helmet.get("defense") instanceof Number) {
            totalDefense += ((Number) helmet.get("defense")).intValue();
        }
        
        // Add boots defense
        Map<String, Object> boots = equipped.get("boots");
        if (boots != null && boots.get("defense") instanceof Number) {
            totalDefense += ((Number) boots.get("defense")).intValue();
        }
        
        return totalDefense;
    }

    /**
     * Drops all items (equipped and inventory) for the given player into the world
     * when they die. Items are scattered around the player's position to avoid stacking.
     */
    private void dropAllItemsForPlayer(GameState state, Player player) {
        int playerId = player.getDatabaseId() > 0 ? player.getDatabaseId() : player.getPeerId();
        float baseX = player.getX();
        float baseY = player.getY();

        int index = 0; // Used to spread items around

        // 1) Drop equipped items first (weapon, armor, helmet, boots)
        Map<String, Map<String, Object>> equipped = EquippedItemRepository.getEquippedItems(playerId);
        for (Map.Entry<String, Map<String, Object>> entry : equipped.entrySet()) {
            String slotType = entry.getKey();
            Map<String, Object> item = entry.getValue();
            if (item == null) continue;

            long inventoryId = ((Number) item.get("inventory_id")).longValue();
            long worldItemId = ((Number) item.get("world_item_id")).longValue();

            float[] pos = computeScatterPosition(baseX, baseY, index++);
            float dropX = pos[0];
            float dropY = pos[1];

            // Unclaim world item and move it to drop position
            boolean unclaimed = WorldItemRepository.unclaimWorldItem(worldItemId, dropX, dropY);
            // Remove from inventory table
            boolean deleted = InventoryRepository.deleteInventoryItem(inventoryId);
            // Clear equipped slot
            EquippedItemRepository.unequipItem(playerId, slotType);

            // Add to game state for sync
            var info = WorldItemRepository.getWorldItemInfo(worldItemId);
            if (info != null) {
                int templateId = ((Number) info.get("item_template_id")).intValue();
                String name = (String) info.get("name");
                WorldItem dropped = new WorldItem(worldItemId, templateId, dropX, dropY, null);
                dropped.setTemplateName(name);
                state.addWorldItem(dropped);
                Logger.info("DEATH DROP (equipped): player=" + playerId + ", slot=" + slotType + ", worldItemId=" + worldItemId +
                        ", invId=" + inventoryId + ", pos=(" + dropX + "," + dropY + ") unclaimed=" + unclaimed + " deleted=" + deleted);
            }
        }

        // 2) Drop remaining inventory items
        var invItems = InventoryRepository.getInventoryForPlayer(playerId);
        for (var row : invItems) {
            long inventoryId = ((Number) row.get("inventory_id")).longValue();
            long worldItemId = ((Number) row.get("world_item_id")).longValue();
            int templateId = ((Number) row.get("item_template_id")).intValue();
            String name = (String) row.get("name");

            float[] pos = computeScatterPosition(baseX, baseY, index++);
            float dropX = pos[0];
            float dropY = pos[1];

            boolean unclaimed = WorldItemRepository.unclaimWorldItem(worldItemId, dropX, dropY);
            boolean deleted = InventoryRepository.deleteInventoryItem(inventoryId);

            WorldItem dropped = new WorldItem(worldItemId, templateId, dropX, dropY, null);
            dropped.setTemplateName(name);
            state.addWorldItem(dropped);
            Logger.info("DEATH DROP (inventory): player=" + playerId + ", worldItemId=" + worldItemId +
                    ", invId=" + inventoryId + ", pos=(" + dropX + "," + dropY + ") unclaimed=" + unclaimed + " deleted=" + deleted);
        }
        
        // IMPORTANT: Refresh the player's cached weapon/armor stats after dropping items
        // This ensures the server-side damage calculation reflects the loss of equipment
        player.refreshEquippedItemsCache();
        Logger.info("DEATH: Refreshed player equipment cache after dropping all items");
    }

    /**
     * Compute a scattered position around (x,y) using a ring pattern with slight jitter.
     */
    private float[] computeScatterPosition(float x, float y, int index) {
        // Arrange items around the player in expanding rings
        int ring = Math.max(0, index / 8); // 8 items per ring
        int posInRing = index % 8;
        double angle = (Math.PI * 2.0) * (posInRing / 8.0) + (ring * 0.3); // slight rotation per ring
        float radius = 48f + ring * 24f; // start at 48px, expand by 24px per ring
        Random rng = new Random();
        float jitterX = (float) ((rng.nextDouble() - 0.5) * 12.0); // small random jitter
        float jitterY = (float) ((rng.nextDouble() - 0.5) * 12.0);
        float dropX = x + (float) (Math.cos(angle) * radius) + jitterX;
        float dropY = y + (float) (Math.sin(angle) * radius) + jitterY;
        return new float[]{dropX, dropY};
    }
}
