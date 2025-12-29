package com.vampireraiders.systems;

import com.vampireraiders.config.ServerConfig;
import com.vampireraiders.database.EnemyTemplateRepository;
import com.vampireraiders.game.Enemy;
import com.vampireraiders.game.EnemyTemplate;
import com.vampireraiders.game.GameState;
import com.vampireraiders.util.Logger;

import java.util.Random;

public class SpawnerSystem {
    private final GameState gameState;
    private final int maxEnemies;
    private final int spawnInterval;
    private long lastSpawnTime;
    private final Random random = new Random();
    private static final int PERF_TEST_ENEMY_COUNT = 100;
    private EnemyTemplate spiderTemplate;

    public SpawnerSystem(GameState gameState) {
        this.gameState = gameState;
        this.maxEnemies = ServerConfig.getInstance().getMaxEnemies();
        this.spawnInterval = ServerConfig.getInstance().getSpawnerInterval();
        this.lastSpawnTime = System.currentTimeMillis();
        
        // Load enemy templates and item drops from database
        EnemyTemplateRepository.loadTemplates();
        com.vampireraiders.database.EnemyItemRepository.loadCache();
        this.spiderTemplate = EnemyTemplateRepository.getByName("Spider");
        
        if (spiderTemplate == null) {
            Logger.error("Failed to load Spider template from database!");
        } else {
            Logger.info("Loaded Spider template: HP=" + spiderTemplate.getHp() + 
                       ", Attack=" + spiderTemplate.getAttack() + 
                       ", Speed=" + spiderTemplate.getMoveSpeed());
        }
    }
    
    public void spawnInitialEnemiesForPerfTest() {
        // Performance test: spawn 200 enemies at startup
        spawnInitialEnemies();
    }
    
    private void spawnInitialEnemies() {
        Logger.debug("Spawning " + PERF_TEST_ENEMY_COUNT + " enemies in circle formation...");
        
        // Spawn enemies in a circle around player spawn point (640, 360)
            float centerX = com.vampireraiders.game.GameWorld.getWorldWidth() / 2f;
            float centerY = com.vampireraiders.game.GameWorld.getWorldHeight() / 2f;
            float circleRadius = (float) ((com.vampireraiders.game.GameWorld.getGridSize() * 64) + 350); // safe zone approx + offset
        
        for (int i = 0; i < PERF_TEST_ENEMY_COUNT; i++) {
            // Calculate angle for this enemy (evenly distributed)
            double angle = (2 * Math.PI * i) / PERF_TEST_ENEMY_COUNT;
            
            // Calculate position on circle
            float x = centerX + (float)(Math.cos(angle) * circleRadius);
            float y = centerY + (float)(Math.sin(angle) * circleRadius);
            
            if (spiderTemplate != null) {
                Enemy enemy = new Enemy(x, y, spiderTemplate);
                gameState.addEnemy(enemy);
            }
        }
        Logger.debug("Performance test enemies spawned in circle: " + gameState.getEnemyCount());
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
            if (spiderTemplate != null) {
                float[] pos = getRandomSpawnPosition();
                Enemy enemy = new Enemy(pos[0], pos[1], spiderTemplate);
                gameState.addEnemy(enemy);
                Logger.debug("Enemy spawned: ID " + enemy.getId() + " Template: " + enemy.getTemplateName());
            }
        }
    }

    /**
     * Get a random spawn position in the red hunting zone (outside moat).
     * Avoids safe zone, moat, and bridges.
     */
    private float[] getRandomSpawnPosition() {
        int maxX = com.vampireraiders.game.GameWorld.getWorldWidth();
        int maxY = com.vampireraiders.game.GameWorld.getWorldHeight();
        for (int attempts = 0; attempts < 100; attempts++) {
            float x = random.nextInt(maxX);
            float y = random.nextInt(maxY);
            // Only spawn in hunting zone (red area outside moat)
            if (com.vampireraiders.game.GameWorld.isInHuntingZone(x, y)) {
                return new float[]{x, y};
            }
        }
        // Fallback: spawn just outside one of the four bridges
        float cx = maxX / 2f, cy = maxY / 2f;
        float moatRadius = 1600f + 1280f + 200f; // safe + moat + offset
        switch (random.nextInt(4)) {
            case 0: return new float[]{cx, cy - moatRadius}; // North
            case 1: return new float[]{cx + moatRadius, cy}; // East
            case 2: return new float[]{cx, cy + moatRadius}; // South
            default: return new float[]{cx - moatRadius, cy}; // West
        }
    }
}
