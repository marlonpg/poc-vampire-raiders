package com.vampireraiders.game;

import com.vampireraiders.systems.SpawnerSystem;
import com.vampireraiders.systems.StateSync;
import com.vampireraiders.util.Logger;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Manages multiple game maps, each running in its own GameLoop thread
 */
public class MapManager {
    private final Map<String, GameLoop> activeLoops = new ConcurrentHashMap<>();
    private final Map<String, Thread> loopThreads = new ConcurrentHashMap<>();
    private final StateSync stateSync;
    private final int tickRate;
    
    public MapManager(StateSync stateSync, int tickRate) {
        this.stateSync = stateSync;
        this.tickRate = tickRate;
    }
    
    /**
     * Load and start a new map with its own GameLoop thread
     */
    public void loadMap(String mapId, String mapFile) {
        Logger.info("[MAP-LOADING] *** loadMap() called with mapId=" + mapId + ", mapFile=" + mapFile);
        Logger.info("[MAP-LOADING] *** activeLoops.containsKey(" + mapId + ") = " + activeLoops.containsKey(mapId));
        
        if (activeLoops.containsKey(mapId)) {
            Logger.warn("Map " + mapId + " is already loaded");
            return;
        }
        
        Logger.info("[MAP-LOADING] Loading map: " + mapId + " from file: " + mapFile);
        
        // Create GameWorld for this map
        GameWorld gameWorld = new GameWorld(mapFile);
        gameWorld.setMapId(mapId);  // Set the map identifier
        gameWorld.setStateSync(stateSync);  // CRITICAL: Set StateSync for broadcasting damage events
        gameWorld.start();  // CRITICAL: Start the game state to enable updates
        Logger.info("[MAP-LOADING] Created GameWorld for " + mapId + " - Tilemap dimensions: " + 
            gameWorld.getTilemap().getMapWidth() + "x" + gameWorld.getTilemap().getMapHeight());
        
        // Create spawner system for this map
        SpawnerSystem spawnerSystem = new SpawnerSystem(gameWorld.getState());
        spawnerSystem.spawnInitialEnemiesForPerfTest();
        
        // Create GameLoop for this map
        GameLoop gameLoop = new GameLoop(mapId, gameWorld, spawnerSystem, stateSync, tickRate);
        
        // Start the game loop in its own thread
        Thread loopThread = new Thread(gameLoop, "GameLoop-" + mapId);
        loopThread.start();
        
        // Store references
        activeLoops.put(mapId, gameLoop);
        loopThreads.put(mapId, loopThread);
        
        Logger.info("Map " + mapId + " loaded and started successfully");
    }
    
    /**
     * Stop a specific map's GameLoop
     */
    public void unloadMap(String mapId) {
        GameLoop gameLoop = activeLoops.get(mapId);
        if (gameLoop == null) {
            Logger.warn("Map " + mapId + " is not loaded");
            return;
        }
        
        Logger.info("Unloading map: " + mapId);
        gameLoop.stop();
        
        // Wait for thread to finish
        Thread thread = loopThreads.get(mapId);
        if (thread != null) {
            try {
                thread.join(5000); // Wait up to 5 seconds
            } catch (InterruptedException e) {
                Logger.error("Interrupted while waiting for map " + mapId + " to stop");
                Thread.currentThread().interrupt();
            }
        }
        
        activeLoops.remove(mapId);
        loopThreads.remove(mapId);
        
        Logger.info("Map " + mapId + " unloaded");
    }
    
    /**
     * Get a specific map's GameLoop
     */
    public GameLoop getMapLoop(String mapId) {
        return activeLoops.get(mapId);
    }
    
    /**
     * Get a specific map's GameWorld
     */
    public GameWorld getGameWorld(String mapId) {
        GameLoop loop = activeLoops.get(mapId);
        return loop != null ? loop.getGameWorld() : null;
    }
    
    /**
     * Teleport a player from one map to another
     */
    public synchronized void teleportPlayer(Player player, String targetMapId, float x, float y) {
        String currentMapId = player.getCurrentMapId();
        
        if (currentMapId.equals(targetMapId)) {
            Logger.warn("Player " + player.getUsername() + " is already in map " + targetMapId);
            return;
        }
        
        GameWorld currentWorld = getGameWorld(currentMapId);
        GameWorld targetWorld = getGameWorld(targetMapId);
        
        if (currentWorld == null) {
            Logger.error("Current map " + currentMapId + " not found for player " + player.getUsername());
            return;
        }
        
        if (targetWorld == null) {
            Logger.error("Target map " + targetMapId + " not found");
            return;
        }
        
        Logger.info("Teleporting player " + player.getUsername() + " from " + currentMapId + " to " + targetMapId);
        
        // Remove from current map
        currentWorld.getState().removePlayer(player.getPeerId());
        
        // Update player state
        player.setCurrentMapId(targetMapId);
        player.setPosition(x, y);
        
        // Add to target map
        targetWorld.getState().addPlayer(player.getPeerId(), player);
        
        // TODO: Send map change notification to client
        Logger.info("Player " + player.getUsername() + " teleported to map " + targetMapId);
    }
    
    /**
     * Stop all maps
     */
    public void stopAll() {
        Logger.info("Stopping all maps...");
        
        for (String mapId : activeLoops.keySet()) {
            unloadMap(mapId);
        }
        
        Logger.info("All maps stopped");
    }
    
    /**
     * Get count of active maps
     */
    public int getActiveMapCount() {
        return activeLoops.size();
    }
}
