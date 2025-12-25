package com.vampireraiders.game;

import com.vampireraiders.systems.CombatSystem;
import com.vampireraiders.systems.SpawnerSystem;
import com.vampireraiders.systems.StateSync;
import com.vampireraiders.util.Logger;

public class GameLoop implements Runnable {
    private final GameWorld gameWorld;
    private final SpawnerSystem spawnerSystem;
    private final StateSync stateSync;
    private final CombatSystem combatSystem;
    private final int tickRate;
    private volatile boolean running = false;
    private long frameCount = 0;

    public GameLoop(GameWorld gameWorld, SpawnerSystem spawnerSystem, StateSync stateSync, int tickRate) {
        this.gameWorld = gameWorld;
        this.spawnerSystem = spawnerSystem;
        this.stateSync = stateSync;
        this.combatSystem = new CombatSystem();
        this.tickRate = tickRate;
    }

    @Override
    public void run() {
        running = true;
        long lastTime = System.nanoTime();
        long nanosPerTick = 1_000_000_000L / tickRate;

        Logger.info("Game loop started at " + tickRate + " ticks/second");

        while (running) {
            long currentTime = System.nanoTime();
            long elapsed = currentTime - lastTime;

            if (elapsed >= nanosPerTick) {
                float deltaTime = (float) elapsed / 1_000_000_000f;
                
                // Update game world
                gameWorld.update(deltaTime);

                // Check combat (player-enemy collisions)
                combatSystem.update(gameWorld.getState(), deltaTime);

                // Spawn enemies
                spawnerSystem.update();

                // Sync state to all clients
                stateSync.broadcastGameState(gameWorld.getState());

                lastTime = currentTime;
                frameCount++;

                if (frameCount % (tickRate * 10) == 0) {
                    Logger.debug("Game loop running - Frame: " + frameCount + 
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

        Logger.info("Game loop stopped");
    }

    public void stop() {
        running = false;
    }

    public long getFrameCount() {
        return frameCount;
    }
}
