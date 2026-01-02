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
    private final ItemDropService itemDropService = new ItemDropService();
    private StateSync stateSync;

    public CombatSystem() {
        this.stateSync = null;
    }

    public void setStateSync(StateSync stateSync) {
        this.stateSync = stateSync;
    }

    public void update(GameState state, float deltaTime) {
        checkPlayerEnemyCollisions(state);
    }

    private void checkPlayerEnemyCollisions(GameState state) {
        for (Player player : state.getAllPlayers().values()) {
            if (!player.isAlive()) continue;

            for (Enemy enemy : state.getAllEnemies()) {
                if (!enemy.isAlive()) continue;

                float distance = calculateDistance(player.getX(), player.getY(), 
                                                 enemy.getX(), enemy.getY());

                if (distance < COLLISION_DISTANCE) {
                    // Enemy damages player with defense reduction (only if enemy can attack)
                    if (enemy.canAttack()) {
                        // Skip damage if player is inside safe zone
                        if (com.vampireraiders.game.GameWorld.isInSafeZone(player.getX(), player.getY())) {
                            continue;
                        }
                        int enemyDamage = enemy.getDamage();
                        int playerDefense = calculatePlayerDefense(player);
                        int effectiveDamage = Math.max(1, enemyDamage - playerDefense);
                        player.takeDamage(effectiveDamage);
                        enemy.recordAttack();  // Update enemy's last attack time
                        Logger.info("Player " + player.getUsername() + " took " + effectiveDamage + " damage (base: " + enemyDamage + ", defense: " + playerDefense + ")");

                        // Broadcast damage event for client-side visual feedback
                        if (stateSync != null) {
                            stateSync.broadcastDamageEvent(player.getPeerId(), "player", effectiveDamage, player.getX(), player.getY());
                        }

                        if (!player.isAlive()) {
                            Logger.info("Player " + player.getUsername() + " died");
                            // On death: drop all equipped + inventory items to the world
                            dropAllItemsForPlayer(state, player);
                            // Respawn at safe zone center (get tilemap from GameWorld)
                            respawnPlayer(player, com.vampireraiders.game.GameWorld.getTilemap());
                        }
                    }
                }
            }
        }
    }

    public void damageEnemy(Enemy enemy, int damage, GameState state) {
        if (!enemy.isAlive()) return;

        enemy.takeDamage(damage);
        Logger.debug("Enemy " + enemy.getId() + " took " + damage + " damage");

        if (!enemy.isAlive()) {
            Logger.debug("Enemy " + enemy.getId() + " defeated");
            rewardKiller(state, enemy);
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

        // Drop item based on enemy template drop rates
        WorldItem dropped = itemDropService.dropFromEnemy(enemy.getTemplateId(), enemy.getX(), enemy.getY());
        if (dropped != null) {
            state.addWorldItem(dropped);
            Logger.info("Dropped world item id=" + dropped.getId() + " template=" + dropped.getItemTemplateId() + " at (" + dropped.getX() + "," + dropped.getY() + ")");
        }
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
