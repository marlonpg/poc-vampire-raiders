package com.vampireraiders;

import com.vampireraiders.config.ServerConfig;
import com.vampireraiders.game.MapManager;
import com.vampireraiders.network.NetworkManager;
import com.vampireraiders.network.NetworkEventListener;
import com.vampireraiders.systems.StateSync;
import com.vampireraiders.util.Logger;

import java.io.IOException;
import java.util.Scanner;

public class VampireRaidersServer implements NetworkEventListener {
    private final ServerConfig config;
    private final NetworkManager networkManager;
    private final StateSync stateSync;
    private final MapManager mapManager;

    public VampireRaidersServer() {
        this.config = ServerConfig.getInstance();
        this.networkManager = new NetworkManager(config.getPort(), null); // GameWorld is now managed per-map
        this.stateSync = new StateSync(networkManager);
        this.mapManager = new MapManager(stateSync, config.getTickRate());
        
        // Connect NetworkManager to MapManager
        this.networkManager.setMapManager(mapManager);
        
        networkManager.addEventListener(this);
    }
    
    public MapManager getMapManager() {
        return mapManager;
    }

    public void start() throws IOException {
        Logger.info("=================================");
        Logger.info("Vampire Raiders Server v0.1.0");
        Logger.info("=================================");
        Logger.info("Starting server on " + config.getHost() + ":" + config.getPort());

        // Load initial maps
        Logger.info("Loading maps...");
        mapManager.loadMap("main-map", "main-map.txt");
        mapManager.loadMap("dungeon-1", "dungeon-1.txt");
        
        // Start network manager
        networkManager.start();

        Logger.info("Server ready for connections!");
    }

    public void stop() {
        Logger.info("Shutting down server...");
        mapManager.stopAll();
        networkManager.stop();
        Logger.info("Server stopped");
    }

    @Override
    public void onClientConnected(int peerId, String ipAddress) {
        Logger.info("Client connected: PeerID=" + peerId + " IP=" + ipAddress);
    }

    @Override
    public void onClientDisconnected(int peerId) {
        // Remove player from all maps (they should only be in one)
        // For now, we'll let the map's GameWorld handle cleanup
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
                        int totalPlayers = 0;
                        int totalEnemies = 0;
                        Logger.info("Active maps: " + server.mapManager.getActiveMapCount());
                        // TODO: Add detailed status per map
                        Logger.info("Status - Total players: " + totalPlayers + ", Total enemies: " + totalEnemies);
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
