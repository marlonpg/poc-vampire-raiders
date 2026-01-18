package com.vampireraiders.game;

import com.vampireraiders.database.PlayerRepository;
import com.vampireraiders.systems.CombatSystem;
import com.vampireraiders.systems.StateSync;
import com.vampireraiders.util.Logger;

import java.util.ArrayList;
import java.util.List;
import java.util.Queue;

public class GameWorld {
    private static Tilemap tilemap;
    private static final int GRID_SIZE = 64;
    private static int WORLD_WIDTH;
    private static int WORLD_HEIGHT;

    private final GameState state;
    private final CombatSystem combatSystem;
    private StateSync stateSync;
    private String mapId = "main-map";  // Track which map this GameWorld represents
    private long lastPlayerSaveTime = 0;
    private static final long PLAYER_SAVE_INTERVAL_MS = 30000; // Save every 30 seconds

    public GameWorld() {
        this(null);
    }
    
    public GameWorld(String mapFile) {
        // Load map
        if (mapFile == null || mapFile.isEmpty()) {
            mapFile = "main-map.txt"; // Default map
        }
        Logger.info("[MAP-LOADING] GameWorld constructor loading map file: " + mapFile);
        tilemap = MapLoader.loadMap(mapFile);
        WORLD_WIDTH = tilemap.getMapWidth() * GRID_SIZE;
        WORLD_HEIGHT = tilemap.getMapHeight() * GRID_SIZE;
        
        this.state = new GameState();
        this.combatSystem = new CombatSystem();
        this.stateSync = null;
    }

    public void setStateSync(StateSync stateSync) {
        this.stateSync = stateSync;
    }
    
    public void setMapId(String mapId) {
        this.mapId = mapId;
    }

    public void update(float deltaTime) {
        if (!state.isRunning()) return;

        // Periodically save all players to database
        long currentTime = System.currentTimeMillis();
        if (currentTime - lastPlayerSaveTime >= PLAYER_SAVE_INTERVAL_MS) {
            for (Player player : state.getAllPlayers().values()) {
                PlayerRepository.savePlayer(player);
            }
            lastPlayerSaveTime = currentTime;
        }

        // Update all players
        for (Player player : state.getAllPlayers().values()) {
            if (player.isAlive()) {
                float oldX = player.getX();
                float oldY = player.getY();
                
                float velX = player.getVelocityX();
                float velY = player.getVelocityY();
                
                player.update(deltaTime);
                
                float newX = player.getX();
                float newY = player.getY();

                // Check if new position is walkable
                if (!isWalkable(newX, newY)) {
                    // Revert to old position if blocked
                    player.setPosition(oldX, oldY);
                } else {
                    // Apply world bounds clamping only if walkable
                    clampPlayerPosition(player);
                }
            }
        }

        // Auto-attack: players fire bullets at nearest enemy
        for (Player player : state.getAllPlayers().values()) {
            if (player.isAlive()) {
                Player nearestEnemy = findNearestPlayer(player.getX(), player.getY());  // Find player to aim at
                // For now, find nearest enemy instead
                Enemy target = findNearestEnemyForAttack(player);
                if (target != null && player.canAttack()) {
                    Bullet bullet = new Bullet(player.getPeerId(), player.getX(), player.getY(), target.getX(), target.getY());
                    state.addBullet(bullet);
                    player.recordAttack();
                }
            }
        }

        // Update all enemies
        for (Enemy enemy : state.getAllEnemies()) {
            if (enemy.isAlive()) {
                // Find nearest player to target
                Player nearestPlayer = findNearestPlayer(enemy.getX(), enemy.getY());
                enemy.update(deltaTime, nearestPlayer);
            }
        }

        // Update all bullets
        for (Bullet bullet : state.getAllBullets()) {
            bullet.update(deltaTime);
        }

        // Check bullet-enemy collisions
        for (Bullet bullet : new ArrayList<>(state.getAllBullets())) {
            for (Enemy enemy : new ArrayList<>(state.getAllEnemies())) {
                if (bullet.collidedWith(enemy)) {
                    Player shooter = state.getPlayer(bullet.getShooterId());
                    int bulletDamage = calculatePlayerDamage(shooter);
                    int effectiveDamage = Math.max(1, bulletDamage - enemy.getDefense());
                    combatSystem.damageEnemy(enemy, effectiveDamage, state);  // Use CombatSystem to handle damage and XP rewards
                    
                    // Broadcast damage event for client-side visual feedback
                    if (stateSync != null) {
                        stateSync.broadcastDamageEvent(mapId, enemy.getId(), "enemy", effectiveDamage, enemy.getX(), enemy.getY());
                    }
                    
                    state.removeBullet(bullet);
                    break;
                }
            }
        }

        // Remove dead enemies and expired bullets
        List<Enemy> enemiesToRemove = new ArrayList<>();
        
        // Process respawning enemies from queue
        Queue<Enemy> deadEnemies = state.getDeadEnemies();
        int queueSize = deadEnemies.size();
        
        // Only check each enemy once per frame to avoid infinite loop
        for (int i = 0; i < queueSize; i++) {
            Enemy deadEnemy = deadEnemies.poll();
            if (deadEnemy == null) break;
            
            if (deadEnemy.isReadyToRespawn()) {
                // Respawn at original position
                deadEnemy.respawnAt(deadEnemy.getOriginalSpawnX(), deadEnemy.getOriginalSpawnY());
                state.addEnemy(deadEnemy);  // Re-add to active enemies list
                Logger.info("Enemy " + deadEnemy.getId() + " (" + deadEnemy.getTemplateName() + ") respawned at (" + deadEnemy.getX() + "," + deadEnemy.getY() + ")");
            } else {
                // Not ready yet, put back in queue
                deadEnemies.offer(deadEnemy);
            }
        }
        
        for (Enemy e : enemiesToRemove) {
            state.removeEnemy(e);
            //System.out.println("[CLEANUP] Removed dead enemy, remaining: " + state.getAllEnemies().size());
        }
        
        List<Bullet> bulletsToRemove = new ArrayList<>();
        for (Bullet b : state.getAllBullets()) {
            if (!b.isAlive()) {
                bulletsToRemove.add(b);
            }
        }
        for (Bullet b : bulletsToRemove) {
            state.removeBullet(b);
        }
    }

    private Enemy findNearestEnemyForAttack(Player player) {
        Enemy nearest = null;
        float attackRange = player.getEquippedAttackRange();  // Use player's equipped weapon range

        for (Enemy enemy : state.getAllEnemies()) {
            if (!enemy.isAlive()) continue;

            float dx = enemy.getX() - player.getX();
            float dy = enemy.getY() - player.getY();
            float distance = (float) Math.sqrt(dx * dx + dy * dy);

            if (distance < attackRange) {
                attackRange = distance;
                nearest = enemy;
            }
        }

        return nearest;
    }

    private void clampPlayerPosition(Player player) {
        float x = player.getX();
        float y = player.getY();
        
        // Clamp to world bounds
        if (x < 0) x = 0;
        if (x > WORLD_WIDTH) x = WORLD_WIDTH;
        if (y < 0) y = 0;
        if (y > WORLD_HEIGHT) y = WORLD_HEIGHT;
        
        player.setPosition(x, y);
    }

    private Player findNearestPlayer(float x, float y) {
        Player nearest = null;
        float closestDistance = Float.MAX_VALUE;

        for (Player player : state.getAllPlayers().values()) {
            if (!player.isAlive()) continue;
            
            float dx = player.getX() - x;
            float dy = player.getY() - y;
            float distance = (float) Math.sqrt(dx * dx + dy * dy);

            if (distance < closestDistance) {
                closestDistance = distance;
                nearest = player;
            }
        }

        return nearest;
    }

    public GameState getState() {
        return state;
    }

    public void start() {
        state.setRunning(true);
    }

    public void stop() {
        state.setRunning(false);
    }

    private int calculatePlayerDamage(Player shooter) {
        if (shooter == null) {
            return 1;  // Fallback when shooter not found
        }

            // Use cached weapon damage instead of querying database
            return 5 + shooter.getCachedWeaponDamage();  // Base damage 15 plus weapon damage
    }
    
    // Utilities
    public static int getWorldWidth() { return WORLD_WIDTH; }
    public static int getWorldHeight() { return WORLD_HEIGHT; }
    public static int getGridSize() { return GRID_SIZE; }
    
    /**
     * Check if position is in safe zone
     */
    public static boolean isInSafeZone(float x, float y) {
        return tilemap.isInSafeZone(x, y);
    }
    
    /**
     * Check if position is walkable for players (tile-based)
     */
    public static boolean isWalkable(float x, float y) {
        return tilemap.isWalkable(x, y);
    }
    
    /**
     * Check if position is walkable for enemies (tile-based)
     */
    public static boolean isEnemyWalkable(float x, float y) {
        return tilemap.isEnemyWalkable(x, y);
    }
    
    /**
     * Check if position is in hunting zone (where enemies spawn)
     */
    public static boolean isInHuntingZone(float x, float y) {
        return tilemap.isInHuntingZone(x, y);
    }
    
    /**
     * Get the tilemap for visualization or debugging
     */
    public static Tilemap getTilemap() {
        return tilemap;
    }
}
