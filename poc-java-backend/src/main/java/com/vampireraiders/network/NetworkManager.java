package com.vampireraiders.network;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.vampireraiders.config.ServerConfig;
import com.vampireraiders.database.EquippedItemRepository;
import com.vampireraiders.database.InventoryRepository;
import com.vampireraiders.database.PlayerRepository;
import com.vampireraiders.database.WorldItemRepository;
import com.vampireraiders.game.GameState;
import com.vampireraiders.game.GameWorld;
import com.vampireraiders.game.Player;
import com.vampireraiders.game.WorldItem;
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
            case "pickup_item":
                handlePickupItem(client, message);
                break;
            case "get_inventory":
                handleGetInventory(client);
                break;
            case "move_inventory_item":
                handleMoveInventoryItem(client, message);
                break;
            case "drop_inventory_item":
                handleDropInventoryItem(client, message);
                break;
            case "equip_item":
                handleEquipItem(client, message);
                break;
            case "unequip_item":
                handleUnequipItem(client, message);
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
        int databaseId = -1;

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
                // Copy database ID from loaded player
                databaseId = dbPlayer.getDatabaseId();
                player.setDatabaseId(databaseId);

                // Load saved stats
                player.setLevel(dbPlayer.getLevel());
                player.setXP(dbPlayer.getXP());
                player.setMaxHealth(dbPlayer.getMaxHealth());
                player.setHealth(dbPlayer.getHealth());

                // If the player was saved dead, respawn them at full health on login
                if (player.getHealth() <= 0) {
                    player.setHealth(player.getMaxHealth());
                }
                Logger.info("Existing player found: " + username + " (dbId=" + databaseId + ") - Level: " + player.getLevel() + ", XP: " + player.getXP());
            }
        } else {
            // Create new player in database
            Player newDbPlayer = PlayerRepository.createNewPlayer(username, password);
            if (newDbPlayer != null) {
                databaseId = newDbPlayer.getDatabaseId();
                player.setDatabaseId(databaseId);
            } else {
                Logger.error("Failed to create new player " + username);
                return;
            }
            Logger.info("New player created: " + username + " (dbId=" + databaseId + ")");
        }

        // Update position for spawn
        player.setInputDirection(0, 0);
        client.setPlayer(player);
        
        // Add player to game world
        gameWorld.getState().addPlayer(client.getPeerId(), player);
        
        Logger.info("Player joined: " + username + " (PeerID: " + client.getPeerId() + ", dbId: " + databaseId + ") - Level: " + player.getLevel() + ", XP: " + player.getXP());

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

    private void handlePickupItem(GameClient client, JsonObject message) {
        if (!message.has("world_item_id")) {
            Logger.debug("PICKUP: Missing world_item_id in message");
            return;
        }

        long worldItemId = message.get("world_item_id").getAsLong();
        Logger.info("PICKUP: Client " + client.getPeerId() + " attempting to pick up item " + worldItemId);
        
        Player player = gameWorld.getState().getPlayer(client.getPeerId());
        if (player == null) {
            Logger.warn("PICKUP: Player not found for client " + client.getPeerId());
            return;
        }

        WorldItem item = gameWorld.getState().getWorldItemById(worldItemId);
        Logger.info("PICKUP: Item lookup result: " + (item != null ? "found at (" + item.getX() + "," + item.getY() + ")" : "NOT FOUND"));
        if (item == null) return;

        double dx = item.getX() - player.getX();
        double dy = item.getY() - player.getY();
        double dist = Math.sqrt(dx * dx + dy * dy);
        double pickupRadius = 96.0; // pixels
        Logger.info("PICKUP: Distance to item: " + dist + ", radius: " + pickupRadius);
        if (dist > pickupRadius) {
            Logger.debug("Pickup rejected: player too far (" + dist + ") from item " + worldItemId);
            return;
        }

        // Use database ID for claiming (set during player creation or loaded from DB)
        int playerId = player.getDatabaseId() > 0 ? player.getDatabaseId() : player.getPeerId();
        Logger.info("PICKUP: Using playerId=" + playerId + " (database=" + player.getDatabaseId() + ", peer=" + player.getPeerId() + ")");
        
        // Check if inventory is full (6 cols x 12 rows = 72 slots max)
        var inventoryItems = InventoryRepository.getInventoryForPlayer(playerId);
        if (inventoryItems.size() >= 72) {
            Logger.info("PICKUP: Inventory full for player " + playerId + ", cannot add item");
            return;
        }
        
        boolean claimed = WorldItemRepository.claimWorldItem(worldItemId, playerId);
        Logger.info("PICKUP: Claim result: " + claimed);
        if (!claimed) {
            Logger.debug("Pickup failed: item already claimed id=" + worldItemId);
            return;
        }

        // Find next available slot in inventory grid (6 cols x 12 rows)
        int[] slot = InventoryRepository.findNextAvailableSlot(playerId, 6, 12);
        int slotX = slot[0];
        int slotY = slot[1];
        Logger.info("PICKUP: Found available slot (" + slotX + "," + slotY + ")");
        
        // Add to inventory at the found slot
        boolean added = InventoryRepository.addInventoryItem(playerId, worldItemId, slotX, slotY);
        Logger.info("PICKUP: Add to inventory result: " + added);
        if (!added) {
            Logger.error("Failed to add world item to inventory id=" + worldItemId + " player=" + playerId);
        }

        item.setClaimedBy(playerId);
        gameWorld.getState().removeWorldItem(item);
        Logger.info("PICKUP: Item removed from world. Pickup complete for item " + worldItemId);
    }

    private void handleGetInventory(GameClient client) {
        Player player = gameWorld.getState().getPlayer(client.getPeerId());
        if (player == null) {
            Logger.warn("GET_INVENTORY: Player not found for peer " + client.getPeerId());
            return;
        }

        int playerId = player.getDatabaseId() > 0 ? player.getDatabaseId() : player.getPeerId();
        Logger.info("GET_INVENTORY: Fetching for playerId=" + playerId + " (peer=" + client.getPeerId() + ", dbId=" + player.getDatabaseId() + ")");
        
        var items = InventoryRepository.getInventoryForPlayer(playerId);
        Logger.info("GET_INVENTORY: Query returned " + items.size() + " items");
        
        JsonObject payload = new JsonObject();
        payload.addProperty("type", "inventory");

        var arr = new com.google.gson.JsonArray();
        for (var row : items) {
            JsonObject obj = new JsonObject();
            obj.addProperty("inventory_id", ((Number) row.get("inventory_id")).longValue());
            obj.addProperty("world_item_id", ((Number) row.get("world_item_id")).longValue());
            obj.addProperty("item_template_id", ((Number) row.get("item_template_id")).intValue());
            obj.addProperty("name", (String) row.get("name"));
            obj.addProperty("type", (String) row.get("type"));
            obj.addProperty("damage", ((Number) row.get("damage")).intValue());
            obj.addProperty("defense", ((Number) row.get("defense")).intValue());
            obj.addProperty("rarity", (String) row.get("rarity"));
            obj.addProperty("stackable", (Boolean) row.get("stackable"));
            obj.addProperty("slot_x", ((Number) row.get("slot_x")).intValue());
            obj.addProperty("slot_y", ((Number) row.get("slot_y")).intValue());
            arr.add(obj);
            Logger.info("  - Item: " + row.get("name") + " at slot (" + row.get("slot_x") + "," + row.get("slot_y") + ")");
        }
        payload.add("items", arr);

        // Add equipped items
        var equipped = EquippedItemRepository.getEquippedItems(playerId);
        JsonObject equippedObj = new JsonObject();
        for (var entry : equipped.entrySet()) {
            String slotType = entry.getKey();
            var item = entry.getValue();
            JsonObject itemObj = new JsonObject();
            itemObj.addProperty("inventory_id", ((Number) item.get("inventory_id")).longValue());
            itemObj.addProperty("world_item_id", ((Number) item.get("world_item_id")).longValue());
            itemObj.addProperty("item_template_id", ((Number) item.get("item_template_id")).intValue());
            itemObj.addProperty("name", (String) item.get("name"));
            itemObj.addProperty("type", (String) item.get("type"));
            itemObj.addProperty("damage", ((Number) item.get("damage")).intValue());
            itemObj.addProperty("defense", ((Number) item.get("defense")).intValue());
            itemObj.addProperty("rarity", (String) item.get("rarity"));
            itemObj.addProperty("stackable", (Boolean) item.get("stackable"));
            equippedObj.add(slotType, itemObj);
            Logger.info("  - Equipped: " + slotType + " = " + item.get("name"));
        }
        payload.add("equipped", equippedObj);

        Logger.info("GET_INVENTORY: Sending " + arr.size() + " items and " + equipped.size() + " equipped items to client");
        sendToClient(client, payload.toString());
    }

    private void handleMoveInventoryItem(GameClient client, JsonObject message) {
        if (!message.has("inventory_id") || !message.has("slot_x") || !message.has("slot_y")) return;
        long inventoryId = message.get("inventory_id").getAsLong();
        int slotX = message.get("slot_x").getAsInt();
        int slotY = message.get("slot_y").getAsInt();
        boolean ok = InventoryRepository.moveInventoryItem(inventoryId, slotX, slotY);
        if (!ok) Logger.debug("Move inventory failed id=" + inventoryId);
    }

    private void handleDropInventoryItem(GameClient client, JsonObject message) {
        if (!message.has("inventory_id")) return;
        Player player = gameWorld.getState().getPlayer(client.getPeerId());
        if (player == null) return;
        long inventoryId = message.get("inventory_id").getAsLong();
        Long worldItemId = InventoryRepository.getWorldItemIdForInventory(inventoryId);
        if (worldItemId == null) return;
        // Remove from inventory
        InventoryRepository.deleteInventoryItem(inventoryId);
        // Unclaim world item back into world at player's current position
        boolean ok = WorldItemRepository.unclaimWorldItem(worldItemId, player.getX(), player.getY());
        if (!ok) return;
        // Fetch info to add into state so clients see the drop
        var info = WorldItemRepository.getWorldItemInfo(worldItemId);
        if (info != null) {
            int templateId = ((Number) info.get("item_template_id")).intValue();
            String name = (String) info.get("name");
            WorldItem wi = new WorldItem(worldItemId, templateId, player.getX(), player.getY(), null);
            wi.setTemplateName(name);
            gameWorld.getState().addWorldItem(wi);
        }
    }

    private void handleEquipItem(GameClient client, JsonObject message) {
        if (!message.has("inventory_id") || !message.has("slot_type")) return;
        
        Player player = gameWorld.getState().getPlayer(client.getPeerId());
        if (player == null) return;
        
        int playerId = player.getDatabaseId() > 0 ? player.getDatabaseId() : player.getPeerId();
        long inventoryId = message.get("inventory_id").getAsLong();
        String slotType = message.get("slot_type").getAsString();
        
        // If there was an old item, unequip it first
        if (message.has("swap_inventory_id")) {
            var swapId = message.get("swap_inventory_id");
            if (!swapId.isJsonNull()) {
                // The old item stays in inventory at the slot where the new item came from
                // So we just need to clear any conflicting equipment slots
            }
        }
        
        boolean ok = EquippedItemRepository.equipItem(playerId, inventoryId, slotType);
        if (ok) {
            Logger.info("EQUIP: Player " + playerId + " equipped item " + inventoryId + " to slot " + slotType);
        }
    }

    private void handleUnequipItem(GameClient client, JsonObject message) {
        if (!message.has("inventory_id") || !message.has("slot_type")) return;
        
        Player player = gameWorld.getState().getPlayer(client.getPeerId());
        if (player == null) return;
        
        int playerId = player.getDatabaseId() > 0 ? player.getDatabaseId() : player.getPeerId();
        String slotType = message.get("slot_type").getAsString();
        
        boolean ok = EquippedItemRepository.unequipItem(playerId, slotType);
        if (ok) {
            Logger.info("UNEQUIP: Player " + playerId + " unequipped item from slot " + slotType);
        }
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
