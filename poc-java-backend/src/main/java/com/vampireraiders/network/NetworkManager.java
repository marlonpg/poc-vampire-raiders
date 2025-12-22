package com.vampireraiders.network;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.vampireraiders.config.ServerConfig;
import com.vampireraiders.database.PlayerRepository;
import com.vampireraiders.game.GameState;
import com.vampireraiders.game.GameWorld;
import com.vampireraiders.game.Player;
import com.vampireraiders.util.Logger;

import java.io.*;
import java.net.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * TCP-based NetworkManager for JSON communication with Godot clients
 */
public class NetworkManager {
    private final int port;
    private final GameWorld gameWorld;
    private final Map<Integer, GameClient> clients = new ConcurrentHashMap<>();
    private final List<NetworkEventListener> listeners = new ArrayList<>();
    private ServerSocket serverSocket;
    private volatile boolean running = false;
    private int nextPeerId = 1;
    private static final long HEARTBEAT_TIMEOUT = 30000; // 30 seconds

    public NetworkManager(int port, GameWorld gameWorld) {
        this.port = port;
        this.gameWorld = gameWorld;
    }

    public void start() throws IOException {
        running = true;
        serverSocket = new ServerSocket(port);
        Logger.info("TCP Server started on port " + port);

        // Start accepting connections
        Thread acceptThread = new Thread(this::acceptConnections);
        acceptThread.setName("NetworkAcceptor");
        acceptThread.setDaemon(false);
        acceptThread.start();

        // Start heartbeat checker
        Thread heartbeatThread = new Thread(this::checkHeartbeats);
        heartbeatThread.setName("HeartbeatChecker");
        heartbeatThread.setDaemon(true);
        heartbeatThread.start();

        Logger.info("Server ready for TCP connections");
    }

    private void acceptConnections() {
        while (running) {
            try {
                Socket clientSocket = serverSocket.accept();
                String clientIP = clientSocket.getInetAddress().getHostAddress();
                int peerId = nextPeerId++;

                Logger.info("New client connected: " + clientIP + " (PeerID: " + peerId + ")");

                GameClient client = new GameClient(peerId, clientIP, clientSocket.getPort());
                clients.put(peerId, client);

                notifyClientConnected(peerId, clientIP);

                // Handle client communication in separate thread
                Thread clientThread = new Thread(() -> handleClient(clientSocket, peerId, client));
                clientThread.setName("ClientHandler-" + peerId);
                clientThread.setDaemon(true);
                clientThread.start();

            } catch (SocketException e) {
                if (running) {
                    Logger.error("Socket error accepting connection: " + e.getMessage());
                }
            } catch (IOException e) {
                if (running) {
                    Logger.error("Error accepting connection", e);
                }
            }
        }
    }

    private void handleClient(Socket clientSocket, int peerId, GameClient client) {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
             PrintWriter writer = new PrintWriter(clientSocket.getOutputStream(), true)) {

            // Store the output stream in the client
            client.setOutputStream(writer);

            String line;
            while (running && (line = reader.readLine()) != null) {
                try {
                    if (line.trim().isEmpty()) continue;
                    
                    JsonObject message = JsonParser.parseString(line).getAsJsonObject();
                    processMessage(peerId, client, message);
                    client.updateHeartbeat();
                } catch (Exception e) {
                    Logger.debug("Invalid message from client " + peerId + ": " + e.getMessage());
                }
            }

        } catch (IOException e) {
            Logger.error("Error handling client " + peerId + ": " + e.getMessage());
        } finally {
            handleClientDisconnect(peerId);
            try {
                clientSocket.close();
            } catch (IOException e) {
                Logger.error("Error closing client socket", e);
            }
        }
    }

    private void processMessage(int peerId, GameClient client, JsonObject message) {
        String type = message.has("type") ? message.get("type").getAsString() : null;

        if (type == null) return;

        switch (type) {
            case "player_join":
                handlePlayerJoin(client, message);
                break;
            case "player_input":
                handlePlayerInput(client, message);
                break;
            case "player_action":
                handlePlayerAction(client, message);
                break;
            case "heartbeat":
                // Just update heartbeat (already done above)
                break;
            default:
                Logger.debug("Unknown message type: " + type);
        }
    }

    private void handlePlayerJoin(GameClient client, JsonObject message) {
        String username = message.get("username").getAsString();
        String password = message.has("password") ? message.get("password").getAsString() : "pass";
        float x = message.get("x").getAsFloat();
        float y = message.get("y").getAsFloat();

        // Always create player with current peer ID
        Player player = new Player(client.getPeerId(), username, x, y);

        // Check if player exists in database and load stats
        if (PlayerRepository.playerExists(username)) {
            // Validate credentials
            if (!PlayerRepository.validateCredentials(username, password)) {
                Logger.warn("Invalid credentials for user: " + username);
                JsonObject error = new JsonObject();
                error.addProperty("type", "auth_error");
                error.addProperty("message", "Invalid username or password");
                sendToClient(client, error.toString());
                return;
            }
            
            Player dbPlayer = PlayerRepository.loadPlayerByUsername(username);
            if (dbPlayer != null) {
                // Load saved stats
                player.setLevel(dbPlayer.getLevel());
                player.setXP(dbPlayer.getXP());
                player.setMaxHealth(dbPlayer.getMaxHealth());
                player.setHealth(dbPlayer.getHealth());

                // If the player was saved dead, respawn them at full health on login
                if (player.getHealth() <= 0) {
                    player.setHealth(player.getMaxHealth());
                }
                Logger.info("Existing player found: " + username + " - Level: " + player.getLevel() + ", XP: " + player.getXP());
            }
        } else {
            // Create new player in database
            PlayerRepository.createNewPlayer(username, password);
            Logger.info("New player created: " + username);
        }

        // Update position for spawn
        player.setInputDirection(0, 0);
        client.setPlayer(player);
        
        // Add player to game world
        gameWorld.getState().addPlayer(client.getPeerId(), player);
        
        Logger.info("Player joined: " + username + " (PeerID: " + client.getPeerId() + ") - Level: " + player.getLevel() + ", XP: " + player.getXP());

        // Send acknowledgment back
        JsonObject ack = new JsonObject();
        ack.addProperty("type", "player_joined");
        ack.addProperty("peer_id", client.getPeerId());
        sendToClient(client, ack.toString());
    }

    private void handlePlayerInput(GameClient client, JsonObject message) {
        float dirX = message.get("dir_x").getAsFloat();
        float dirY = message.get("dir_y").getAsFloat();

        if (client.getPlayer() != null) {
            client.getPlayer().setInputDirection(dirX, dirY);
            notifyClientInput(client.getPeerId(), "move", dirX, dirY);
        }
    }

    private void handlePlayerAction(GameClient client, JsonObject message) {
        String action = message.get("action").getAsString();
        Logger.debug("Player " + client.getPeerId() + " performed action: " + action);
    }

    private void handleClientDisconnect(int peerId) {
        GameClient client = clients.remove(peerId);
        if (client != null) {
            // Save player state on disconnect
            if (client.getPlayer() != null) {
                PlayerRepository.savePlayer(client.getPlayer());
                Logger.info("Saved player " + client.getPlayer().getUsername() + " on disconnect");
            }
            notifyClientDisconnected(peerId);
            Logger.info("Client disconnected: PeerID " + peerId);
        }
    }

    private void checkHeartbeats() {
        while (running) {
            try {
                Thread.sleep(5000); // Check every 5 seconds
                long currentTime = System.currentTimeMillis();

                List<Integer> disconnected = new ArrayList<>();
                for (Map.Entry<Integer, GameClient> entry : clients.entrySet()) {
                    if (currentTime - entry.getValue().getLastHeartbeat() > HEARTBEAT_TIMEOUT) {
                        disconnected.add(entry.getKey());
                    }
                }

                for (int peerId : disconnected) {
                    GameClient client = clients.remove(peerId);
                    notifyClientDisconnected(peerId);
                    Logger.info("Client disconnected (timeout): PeerID " + peerId);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
    }

    public void sendToClient(GameClient client, String message) {
        if (client.getOutputStream() != null) {
            client.getOutputStream().println(message);
            client.getOutputStream().flush();
        }
    }

    public void broadcastMessage(String message, int exceptPeerId) {
        for (GameClient client : clients.values()) {
            if (client.getPeerId() != exceptPeerId) {
                sendToClient(client, message);
            }
        }
    }

    public void broadcastMessageToAll(String message) {
        for (GameClient client : clients.values()) {
            sendToClient(client, message);
        }
    }

    public void stop() {
        running = false;
        try {
            if (serverSocket != null && !serverSocket.isClosed()) {
                serverSocket.close();
            }
        } catch (IOException e) {
            Logger.error("Error closing server socket", e);
        }
        Logger.info("NetworkManager stopped");
    }

    // Event notification methods
    public void addEventListener(NetworkEventListener listener) {
        listeners.add(listener);
    }

    public void removeEventListener(NetworkEventListener listener) {
        listeners.remove(listener);
    }

    private void notifyClientConnected(int peerId, String ipAddress) {
        for (NetworkEventListener listener : listeners) {
            listener.onClientConnected(peerId, ipAddress);
        }
    }

    private void notifyClientDisconnected(int peerId) {
        for (NetworkEventListener listener : listeners) {
            listener.onClientDisconnected(peerId);
        }
    }

    private void notifyClientInput(int peerId, String inputType, float dirX, float dirY) {
        for (NetworkEventListener listener : listeners) {
            listener.onClientInput(peerId, inputType, dirX, dirY);
        }
    }

    // Getters
    public Map<Integer, GameClient> getClients() {
        return new HashMap<>(clients);
    }

    public int getClientCount() {
        return clients.size();
    }
}
