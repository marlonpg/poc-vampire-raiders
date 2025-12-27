package com.vampireraiders;

import com.vampireraiders.config.ServerConfig;
import com.vampireraiders.game.GameLoop;
import com.vampireraiders.game.GameWorld;
import com.vampireraiders.network.NetworkManager;
import com.vampireraiders.network.NetworkEventListener;
import com.vampireraiders.systems.SpawnerSystem;
import com.vampireraiders.systems.StateSync;
import com.vampireraiders.util.Logger;

import java.io.IOException;
import java.util.Scanner;

public class VampireRaidersServer implements NetworkEventListener {
    private final ServerConfig config;
    private final NetworkManager networkManager;
    private final GameWorld gameWorld;
    private final SpawnerSystem spawnerSystem;
    private final StateSync stateSync;
    private final GameLoop gameLoop;
    private Thread gameLoopThread;

    public VampireRaidersServer() {
        this.config = ServerConfig.getInstance();
        this.gameWorld = new GameWorld();
        this.spawnerSystem = new SpawnerSystem(gameWorld.getState());
        this.networkManager = new NetworkManager(config.getPort(), gameWorld);
        this.stateSync = new StateSync(networkManager);
        this.gameWorld.setStateSync(stateSync);  // Set the StateSync reference in GameWorld
        this.gameLoop = new GameLoop(gameWorld, spawnerSystem, stateSync, config.getTickRate());
        
        networkManager.addEventListener(this);
    }

    public void start() throws IOException {
        Logger.info("=================================");
        Logger.info("Vampire Raiders Server v0.1.0");
        Logger.info("=================================");
        Logger.info("Starting server on " + config.getHost() + ":" + config.getPort());

        // Spawn initial enemies for performance testing
        spawnerSystem.spawnInitialEnemiesForPerfTest();

        // Start network manager
        networkManager.start();

        // Start game world
        gameWorld.start();

        // Start game loop
        gameLoopThread = new Thread(gameLoop);
        gameLoopThread.setName("GameLoop");
        gameLoopThread.start();

        Logger.info("Server ready for connections!");
    }

    public void stop() {
        Logger.info("Shutting down server...");
        gameLoop.stop();
        networkManager.stop();
        gameWorld.stop();

        try {
            if (gameLoopThread != null) {
                gameLoopThread.join(5000);
            }
        } catch (InterruptedException e) {
            Logger.error("Error waiting for game loop thread", e);
        }

        Logger.info("Server stopped");
    }

    @Override
    public void onClientConnected(int peerId, String ipAddress) {
        Logger.info("Client connected: PeerID=" + peerId + " IP=" + ipAddress);
    }

    @Override
    public void onClientDisconnected(int peerId) {
        gameWorld.getState().removePlayer(peerId);
        Logger.info("Client disconnected: PeerID=" + peerId);
    }

    @Override
    public void onClientInput(int peerId, String inputType, float dirX, float dirY) {
        // Input already handled in NetworkManager, just log for debugging
    }

    @Override
    public void onServerError(String errorMessage) {
        Logger.error("Server error: " + errorMessage);
    }

    public static void main(String[] args) {
        VampireRaidersServer server = new VampireRaidersServer();

        try {
            server.start();

            // Command loop for server control
            Scanner scanner = new Scanner(System.in);
            String command;
            while (true) {
                System.out.print("> ");
                command = scanner.nextLine().trim().toLowerCase();

                switch (command) {
                    case "status":
                        int players = server.gameWorld.getState().getPlayerCount();
                        int enemies = server.gameWorld.getState().getEnemyCount();
                        Logger.info("Status - Players: " + players + ", Enemies: " + enemies);
                        break;
                    case "help":
                        System.out.println("Commands: status, help, stop");
                        break;
                    case "stop":
                    case "exit":
                    case "quit":
                        server.stop();
                        System.exit(0);
                        break;
                    default:
                        if (!command.isEmpty()) {
                            System.out.println("Unknown command. Type 'help' for available commands.");
                        }
                }
            }

        } catch (IOException e) {
            Logger.error("Failed to start server", e);
            System.exit(1);
        }
    }
}
