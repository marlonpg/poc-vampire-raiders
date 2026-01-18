package com.vampireraiders.game;

import com.vampireraiders.systems.CombatSystem;
import com.vampireraiders.systems.SpawnerSystem;
import com.vampireraiders.systems.StateSync;
import com.vampireraiders.util.Logger;

public class GameLoop implements Runnable {
    private final String mapId;
    private final GameWorld gameWorld;
    private final SpawnerSystem spawnerSystem;
    private final StateSync stateSync;
    private final CombatSystem combatSystem;
    private final int tickRate;
    private volatile boolean running = false;
    private long frameCount = 0;

    public GameLoop(String mapId, GameWorld gameWorld, SpawnerSystem spawnerSystem, StateSync stateSync, int tickRate) {
        this.mapId = mapId;
        this.gameWorld = gameWorld;
        this.spawnerSystem = spawnerSystem;
        this.stateSync = stateSync;
        this.combatSystem = new CombatSystem();
        this.combatSystem.setStateSync(stateSync);  // Set StateSync for damage event broadcasting
        this.tickRate = tickRate;
    }
    
    public String getMapId() {
        return mapId;
    }
    
    public GameWorld getGameWorld() {
        return gameWorld;
    }

    @Override
    public void run() {
        running = true;
        long lastTime = System.nanoTime();
        long nanosPerTick = 1_000_000_000L / tickRate;

        Logger.info("Game loop started for map '" + mapId + "' at " + tickRate + " ticks/second");

        while (running) {
            long currentTime = System.nanoTime();
            long elapsed = currentTime - lastTime;

            if (elapsed >= nanosPerTick) {
                float deltaTime = (float) elapsed / 1_000_000_000f;
                
                // Update game world
                gameWorld.update(deltaTime);

                // Check combat (player-enemy collisions)
                combatSystem.update(mapId, gameWorld.getState(), deltaTime);

                // Spawn enemies
                spawnerSystem.update();

                // Sync state to clients in this map only
                stateSync.broadcastGameState(mapId, gameWorld.getState());

                lastTime = currentTime;
                frameCount++;

                if (frameCount % (tickRate * 10) == 0) {
                    Logger.debug("Game loop [" + mapId + "] - Frame: " + frameCount + 
                               ", Players: " + gameWorld.getState().getPlayerCount() +
                               ", Enemies: " + gameWorld.getState().getEnemyCount());
                }
            } else {
                // Sleep to avoid busy waiting
                try {
                    Thread.sleep(1);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }

        Logger.info("Game loop stopped for map '" + mapId + "'");
    }

    public void stop() {
        running = false;
    }

    public long getFrameCount() {
        return frameCount;
    }
}
