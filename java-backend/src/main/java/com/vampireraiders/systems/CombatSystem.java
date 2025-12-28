package com.vampireraiders.systems;

import com.vampireraiders.database.EquippedItemRepository;
import com.vampireraiders.game.Enemy;
import com.vampireraiders.game.GameState;
import com.vampireraiders.game.Player;
import com.vampireraiders.game.WorldItem;
import com.vampireraiders.systems.ItemDropService;
import com.vampireraiders.util.Logger;

import java.util.Map;

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
}
