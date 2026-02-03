package com.vampireraiders.systems;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.vampireraiders.game.*;
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
            playerObj.addProperty("attack_range", player.getEquippedAttackRange());
            playerObj.addProperty("dir_x", player.getVelocityX());
            playerObj.addProperty("dir_y", player.getVelocityY());
            playersArray.add(playerObj);
        }
        message.add("players", playersArray);

        // Serialize enemies
        JsonArray enemiesArray = new JsonArray();
        for (Enemy enemy : state.getAllEnemies()) {
            JsonObject enemyObj = new JsonObject();
            enemyObj.addProperty("id", enemy.getId());
            enemyObj.addProperty("template_id", enemy.getTemplateId());
            enemyObj.addProperty("x", enemy.getX());
            enemyObj.addProperty("y", enemy.getY());
            enemyObj.addProperty("health", enemy.getHealth());
            enemyObj.addProperty("max_health", enemy.getMaxHealth());
            enemyObj.addProperty("type", enemy.getTemplateName());
            enemyObj.addProperty("level", enemy.getLevel());
            enemyObj.addProperty("alive", enemy.isAlive());
            
            // Telegraph attack data
            enemyObj.addProperty("attack_state", enemy.getAttackState().toString());
            enemyObj.addProperty("telegraph_target_x", enemy.getTelegraphTargetX());
            enemyObj.addProperty("telegraph_target_y", enemy.getTelegraphTargetY());
            enemyObj.addProperty("telegraph_start_time", enemy.getTelegraphStartTime());
            enemyObj.addProperty("telegraph_duration_ms", enemy.getTelegraphDurationMs());
            
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

        // Serialize melee attacks
        long currentTimeMs = System.currentTimeMillis();
        JsonArray meleeArray = new JsonArray();
        for (MeleeAttack attack : state.getAllMeleeAttacks()) {
            if (attack.isActive(currentTimeMs)) {
                JsonObject meleeObj = new JsonObject();
                meleeObj.addProperty("id", attack.getId());
                meleeObj.addProperty("player_id", attack.getPlayerId());
                meleeObj.addProperty("x", attack.getX());
                meleeObj.addProperty("y", attack.getY());
                meleeObj.addProperty("radius", attack.getRadius());
                meleeObj.addProperty("start_time", attack.getStartTimeMs());
                meleeObj.addProperty("duration_ms", attack.getDurationMs());
                meleeObj.addProperty("direction_degrees", attack.getDirectionDegrees());
                meleeArray.add(meleeObj);
            }
        }
        message.add("melee_attacks", meleeArray);

        // Serialize world items (unclaimed drops)
        JsonArray worldItemsArray = new JsonArray();
        for (WorldItem item : state.getWorldItems()) {
            JsonObject itemObj = new JsonObject();
            itemObj.addProperty("id", item.getId());
            itemObj.addProperty("item_template_id", item.getItemTemplateId());
            itemObj.addProperty("name", item.getTemplateName() != null ? item.getTemplateName() : "Item");
            itemObj.addProperty("type", item.getItemType() != null ? item.getItemType() : "");
            itemObj.addProperty("x", item.getX());
            itemObj.addProperty("y", item.getY());
            itemObj.addProperty("claimed_by", item.getClaimedBy());
            itemObj.addProperty("has_mods", item.hasMods());
            worldItemsArray.add(itemObj);
        }
        message.add("world_items", worldItemsArray);

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

    /**
     * Broadcast a damage event to all clients for visual feedback
     * @param targetId - ID of damaged entity (enemy id or peer_id for players)
     * @param targetType - "enemy" or "player"
     * @param damage - effective damage dealt
     * @param x - world x position
     * @param y - world y position
     */
    public void broadcastDamageEvent(int targetId, String targetType, int damage, float x, float y) {
        JsonObject message = new JsonObject();
        message.addProperty("type", "damage_event");
        message.addProperty("target_id", targetId);
        message.addProperty("target_type", targetType);
        message.addProperty("damage", damage);
        message.addProperty("x", x);
        message.addProperty("y", y);
        
        if (networkManager != null) {
            networkManager.broadcastMessageToAll(message.toString());
        }
    }
}
