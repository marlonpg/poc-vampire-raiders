package com.vampireraiders.systems;

import com.vampireraiders.config.ServerConfig;
import com.vampireraiders.database.EnemyTemplateRepository;
import com.vampireraiders.game.Enemy;
import com.vampireraiders.game.EnemyTemplate;
import com.vampireraiders.game.GameState;
import com.vampireraiders.game.GameWorld;
import com.vampireraiders.game.TileType;
import com.vampireraiders.game.Tilemap;
import com.vampireraiders.util.Logger;

import java.util.List;
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
        Logger.debug("Spawning " + PERF_TEST_ENEMY_COUNT + " enemies in map spawn zones...");
        
        Tilemap tilemap = GameWorld.getTilemap();
        if (tilemap == null) {
            Logger.error("Tilemap not loaded, cannot spawn enemies!");
            return;
        }
        
        // Spawn across different level zones (PV1-4)
        EnemyTemplate spiderTemplate = EnemyTemplateRepository.getByName("Spider");
        EnemyTemplate wormTemplate = EnemyTemplateRepository.getByName("Worm");
        EnemyTemplate wildDogTemplate = EnemyTemplateRepository.getByName("Wild Dog");
        EnemyTemplate goblinTemplate = EnemyTemplateRepository.getByName("Goblin");
        
        int spidersToSpawn = PERF_TEST_ENEMY_COUNT / 4;
        int wormsToSpawn = PERF_TEST_ENEMY_COUNT / 4;
        int dogsToSpawn = PERF_TEST_ENEMY_COUNT / 4;
        int goblinsToSpawn = PERF_TEST_ENEMY_COUNT - spidersToSpawn - wormsToSpawn - dogsToSpawn;
        
        // Spawn Spiders in PV1 zones
        if (spiderTemplate != null) {
            List<Tilemap.TilePosition> pv1Zones = tilemap.getSpawnZones(1);
            for (int i = 0; i < spidersToSpawn && !pv1Zones.isEmpty(); i++) {
                Tilemap.TilePosition pos = pv1Zones.get(random.nextInt(pv1Zones.size()));
                Enemy enemy = new Enemy(pos.worldX, pos.worldY, spiderTemplate);
                gameState.addEnemy(enemy);
            }
        }
        
        // Spawn Worms in PV2 zones
        if (wormTemplate != null) {
            List<Tilemap.TilePosition> pv2Zones = tilemap.getSpawnZones(2);
            for (int i = 0; i < wormsToSpawn && !pv2Zones.isEmpty(); i++) {
                Tilemap.TilePosition pos = pv2Zones.get(random.nextInt(pv2Zones.size()));
                Enemy enemy = new Enemy(pos.worldX, pos.worldY, wormTemplate);
                gameState.addEnemy(enemy);
            }
        }
        
        // Spawn Wild Dogs in PV3 zones
        if (wildDogTemplate != null) {
            List<Tilemap.TilePosition> pv3Zones = tilemap.getSpawnZones(3);
            for (int i = 0; i < dogsToSpawn && !pv3Zones.isEmpty(); i++) {
                Tilemap.TilePosition pos = pv3Zones.get(random.nextInt(pv3Zones.size()));
                Enemy enemy = new Enemy(pos.worldX, pos.worldY, wildDogTemplate);
                gameState.addEnemy(enemy);
            }
        }
        
        // Spawn Goblins in PV4 zones
        if (goblinTemplate != null) {
            List<Tilemap.TilePosition> pv4Zones = tilemap.getSpawnZones(4);
            for (int i = 0; i < goblinsToSpawn && !pv4Zones.isEmpty(); i++) {
                Tilemap.TilePosition pos = pv4Zones.get(random.nextInt(pv4Zones.size()));
                Enemy enemy = new Enemy(pos.worldX, pos.worldY, goblinTemplate);
                gameState.addEnemy(enemy);
            }
        }
        
        Logger.debug("Performance test enemies spawned in map zones: " + gameState.getEnemyCount());
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

        Tilemap tilemap = GameWorld.getTilemap();
        if (tilemap == null) {
            return;
        }

        // Spawn 1-2 enemies per spawn cycle, distributed across levels
        int spawnCount = random.nextInt(2) + 1;
        for (int i = 0; i < spawnCount && gameState.getEnemyCount() < maxEnemies; i++) {
            // Choose random spawn level (1-4)
            int level = random.nextInt(4) + 1;
            EnemyTemplate template = getTemplateForLevel(level);
            
            if (template != null) {
                float[] pos = getRandomSpawnPosition(tilemap, level);
                Enemy enemy = new Enemy(pos[0], pos[1], template);
                gameState.addEnemy(enemy);
                Logger.debug("Enemy spawned: ID " + enemy.getId() + " Template: " + enemy.getTemplateName() + " Level: " + level);
            }
        }
    }
    
    private EnemyTemplate getTemplateForLevel(int level) {
        switch (level) {
            case 1: return EnemyTemplateRepository.getByName("Spider");
            case 2: return EnemyTemplateRepository.getByName("Worm");
            case 3: return EnemyTemplateRepository.getByName("Wild Dog");
            case 4: return EnemyTemplateRepository.getByName("Goblin");
            default: return EnemyTemplateRepository.getByName("Spider");
        }
    }

    /**
     * Get a random spawn position in the specified level's spawn zone.
     */
    private float[] getRandomSpawnPosition(Tilemap tilemap, int level) {
        List<Tilemap.TilePosition> spawnZones = tilemap.getSpawnZones(level);
        
        if (spawnZones.isEmpty()) {
            // Fallback to any PVE zone
            spawnZones = tilemap.getTilesOfType(TileType.PVE);
        }
        
        if (spawnZones.isEmpty()) {
            // Last resort: spawn at world center
            return new float[]{tilemap.getMapWidth() * 32f, tilemap.getMapHeight() * 32f};
        }
        
        Tilemap.TilePosition pos = spawnZones.get(random.nextInt(spawnZones.size()));
        return new float[]{pos.worldX, pos.worldY};
    }
}
