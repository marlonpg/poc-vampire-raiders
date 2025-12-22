package com.vampireraiders.game;

import com.vampireraiders.database.PlayerRepository;
import com.vampireraiders.systems.CombatSystem;
import java.util.ArrayList;
import java.util.List;

public class GameWorld {
    private static final int WORLD_WIDTH = 8192;  // 256 tiles * 32 pixels (Lorencia-sized map)
    private static final int WORLD_HEIGHT = 8192; // 256 tiles * 32 pixels
    private static final int GRID_SIZE = 32;

    private final GameState state;
    private final CombatSystem combatSystem;
    private long lastPlayerSaveTime = 0;
    private static final long PLAYER_SAVE_INTERVAL_MS = 30000; // Save every 30 seconds

    public GameWorld() {
        this.state = new GameState();
        this.combatSystem = new CombatSystem();
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
                player.update(deltaTime);
                clampPlayerPosition(player);
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
                    int bulletDamage = 50;  // One-shot most enemies
                    System.out.println("[COLLISION] Bullet hit enemy! Damage: " + bulletDamage + ", Enemy health: " + enemy.getHealth() + ", Alive: " + enemy.isAlive());
                    combatSystem.damageEnemy(enemy, bulletDamage, state);  // Use CombatSystem to handle damage and XP rewards
                    state.removeBullet(bullet);
                    break;
                }
            }
        }

        // Remove dead enemies and expired bullets
        List<Enemy> enemiesToRemove = new ArrayList<>();
        for (Enemy e : state.getAllEnemies()) {
            if (!e.isAlive()) {
                enemiesToRemove.add(e);
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
        float closestDistance = 300f;  // Attack range

        for (Enemy enemy : state.getAllEnemies()) {
            if (!enemy.isAlive()) continue;

            float dx = enemy.getX() - player.getX();
            float dy = enemy.getY() - player.getY();
            float distance = (float) Math.sqrt(dx * dx + dy * dy);

            if (distance < closestDistance) {
                closestDistance = distance;
                nearest = enemy;
            }
        }

        return nearest;
    }

    private void clampPlayerPosition(Player player) {
        float x = player.getX();
        float y = player.getY();
        
        if (x < 0) x = 0;
        if (x > WORLD_WIDTH) x = WORLD_WIDTH;
        if (y < 0) y = 0;
        if (y > WORLD_HEIGHT) y = WORLD_HEIGHT;
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

    public int getWorldWidth() { return WORLD_WIDTH; }
    public int getWorldHeight() { return WORLD_HEIGHT; }
    public int getGridSize() { return GRID_SIZE; }

    public void start() {
        state.setRunning(true);
    }

    public void stop() {
        state.setRunning(false);
    }
}
