package com.vampireraiders.systems;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.vampireraiders.game.Bullet;
import com.vampireraiders.game.Enemy;
import com.vampireraiders.game.GameState;
import com.vampireraiders.game.Player;
import com.vampireraiders.network.NetworkManager;

public class StateSync {
    private long lastSyncTime = 0;
    private final int syncIntervalMs = 16; // ~60 Hz
    private final NetworkManager networkManager;

    public StateSync(NetworkManager networkManager) {
        this.networkManager = networkManager;
    }

    public JsonObject createGameStateMessage(GameState state) {
        JsonObject message = new JsonObject();
        message.addProperty("type", "game_state");
        message.addProperty("world_time", state.getWorldTime());

        // Serialize players
        JsonArray playersArray = new JsonArray();
        for (Player player : state.getAllPlayers().values()) {
            JsonObject playerObj = new JsonObject();
            playerObj.addProperty("peer_id", player.getPeerId());
            playerObj.addProperty("username", player.getUsername());
            playerObj.addProperty("x", player.getX());
            playerObj.addProperty("y", player.getY());
            playerObj.addProperty("health", player.getHealth());
            playerObj.addProperty("max_health", player.getMaxHealth());
            playerObj.addProperty("xp", player.getXP());
            playerObj.addProperty("level", player.getLevel());
            playerObj.addProperty("alive", player.isAlive());
            playersArray.add(playerObj);
        }
        message.add("players", playersArray);

        // Serialize enemies
        JsonArray enemiesArray = new JsonArray();
        for (Enemy enemy : state.getAllEnemies()) {
            JsonObject enemyObj = new JsonObject();
            enemyObj.addProperty("id", enemy.getId());
            enemyObj.addProperty("x", enemy.getX());
            enemyObj.addProperty("y", enemy.getY());
            enemyObj.addProperty("health", enemy.getHealth());
            enemyObj.addProperty("max_health", enemy.getMaxHealth());
            enemyObj.addProperty("type", enemy.getType().toString());
            enemyObj.addProperty("alive", enemy.isAlive());
            enemiesArray.add(enemyObj);
        }
        message.add("enemies", enemiesArray);

        // Serialize bullets
        JsonArray bulletsArray = new JsonArray();
        for (Bullet bullet : state.getAllBullets()) {
            JsonObject bulletObj = new JsonObject();
            bulletObj.addProperty("id", bullet.getId());
            bulletObj.addProperty("shooter_id", bullet.getShooterId());
            bulletObj.addProperty("x", bullet.getX());
            bulletObj.addProperty("y", bullet.getY());
            bulletObj.addProperty("vx", bullet.getVx());
            bulletObj.addProperty("vy", bullet.getVy());
            bulletsArray.add(bulletObj);
        }
        message.add("bullets", bulletsArray);

        return message;
    }

    public void broadcastGameState(GameState state) {
        long currentTime = System.currentTimeMillis();
        if (currentTime - lastSyncTime < syncIntervalMs) {
            return; // Skip sync if too soon
        }

        lastSyncTime = currentTime;

        JsonObject message = createGameStateMessage(state);
        if (networkManager != null) {
            networkManager.broadcastMessageToAll(message.toString());
        }
    }

    public JsonObject createPlayerDamageMessage(int victimId, int damage, int remainingHealth) {
        JsonObject message = new JsonObject();
        message.addProperty("type", "player_damage");
        message.addProperty("victim_id", victimId);
        message.addProperty("damage", damage);
        message.addProperty("remaining_health", remainingHealth);
        return message;
    }

    public JsonObject createPlayerDeathMessage(int playerId) {
        JsonObject message = new JsonObject();
        message.addProperty("type", "player_death");
        message.addProperty("player_id", playerId);
        return message;
    }

    public JsonObject createEnemySpawnMessage(Enemy enemy) {
        JsonObject message = new JsonObject();
        message.addProperty("type", "enemy_spawn");
        message.addProperty("id", enemy.getId());
        message.addProperty("x", enemy.getX());
        message.addProperty("y", enemy.getY());
        message.addProperty("type", enemy.getType().toString());
        return message;
    }

    public JsonObject createEnemyDamageMessage(int enemyId, int damage, int remainingHealth) {
        JsonObject message = new JsonObject();
        message.addProperty("type", "enemy_damage");
        message.addProperty("enemy_id", enemyId);
        message.addProperty("damage", damage);
        message.addProperty("remaining_health", remainingHealth);
        return message;
    }

    public JsonObject createEnemyDeathMessage(int enemyId, int xpReward) {
        JsonObject message = new JsonObject();
        message.addProperty("type", "enemy_death");
        message.addProperty("enemy_id", enemyId);
        message.addProperty("xp_reward", xpReward);
        return message;
    }
}
