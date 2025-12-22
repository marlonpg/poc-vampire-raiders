package com.vampireraiders.systems;

import com.vampireraiders.config.ServerConfig;
import com.vampireraiders.game.Enemy;
import com.vampireraiders.game.GameState;
import com.vampireraiders.util.Logger;

import java.util.Random;

public class SpawnerSystem {
    private final GameState gameState;
    private final int maxEnemies;
    private final int spawnInterval;
    private long lastSpawnTime;
    private final Random random = new Random();
    private static final int SPAWN_RADIUS = 500;
    private static final int SPAWN_MIN_DISTANCE = 300;

    public SpawnerSystem(GameState gameState) {
        this.gameState = gameState;
        this.maxEnemies = ServerConfig.getInstance().getMaxEnemies();
        this.spawnInterval = ServerConfig.getInstance().getSpawnerInterval();
        this.lastSpawnTime = System.currentTimeMillis();
    }

    public void update() {
        long currentTime = System.currentTimeMillis();
        if (currentTime - lastSpawnTime >= spawnInterval) {
            spawnEnemies();
            lastSpawnTime = currentTime;
        }
    }

    private void spawnEnemies() {
        if (gameState.getEnemyCount() >= maxEnemies) {
            return;
        }

        if (gameState.getPlayerCount() == 0) {
            return;
        }

        // Spawn 1-2 enemies per spawn cycle
        int spawnCount = random.nextInt(2) + 1;
        for (int i = 0; i < spawnCount && gameState.getEnemyCount() < maxEnemies; i++) {
            Enemy enemy = Enemy.createRandomEnemy(
                getRandomSpawnX(),
                getRandomSpawnY()
            );
            gameState.addEnemy(enemy);
            Logger.debug("Enemy spawned: ID " + enemy.getId() + " Type: " + enemy.getType());
        }
    }

    private float getRandomSpawnX() {
        return random.nextInt(1280);
    }

    private float getRandomSpawnY() {
        return random.nextInt(720);
    }
}
