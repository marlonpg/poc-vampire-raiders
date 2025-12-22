package com.vampireraiders.systems;

import com.vampireraiders.game.Enemy;
import com.vampireraiders.game.GameState;
import com.vampireraiders.game.Player;
import com.vampireraiders.util.Logger;

public class CombatSystem {
    private static final float COLLISION_DISTANCE = 40f;
    private static final float PLAYER_ATTACK_COOLDOWN = 0.5f; // seconds

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
                    // Enemy damages player
                    player.takeDamage(enemy.getDamage());
                    Logger.info("Player " + player.getUsername() + " took " + enemy.getDamage() + " damage");

                    if (!player.isAlive()) {
                        Logger.info("Player " + player.getUsername() + " died");
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
            Logger.debug("Player " + nearestPlayer.getUsername() + " gained " + xpReward + " XP");
        }
    }

    private float calculateDistance(float x1, float y1, float x2, float y2) {
        float dx = x1 - x2;
        float dy = y1 - y2;
        return (float) Math.sqrt(dx * dx + dy * dy);
    }
}
