package com.vampireraiders.network;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.vampireraiders.config.ServerConfig;
import com.vampireraiders.database.EquippedItemRepository;
import com.vampireraiders.database.InventoryRepository;
import com.vampireraiders.database.ItemTemplateRepository;
import com.vampireraiders.database.PlayerRepository;
import com.vampireraiders.database.WorldItemRepository;
import com.vampireraiders.game.GameState;
import com.vampireraiders.game.GameWorld;
import com.vampireraiders.game.Player;
import com.vampireraiders.game.Tilemap;
import com.vampireraiders.game.WorldItem;
import com.vampireraiders.util.Logger;

import java.io.*;
import java.net.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.nio.charset.StandardCharsets;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

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

    // UDP support for low-latency inputs (hybrid transport)
    private DatagramSocket udpSocket;
    private Thread udpThread;
    private final Map<Integer, InetSocketAddress> udpClients = new ConcurrentHashMap<>();
    private final Map<Integer, String> udpTokens = new ConcurrentHashMap<>();
    private final Map<Integer, Long> udpLastSeq = new ConcurrentHashMap<>();
    private final Map<Integer, TokenBucket> udpBuckets = new ConcurrentHashMap<>();

    private static final int UDP_INPUT_RATE = 30; // per second
    private static final int UDP_BUCKET_CAPACITY = 60; // burst allowance

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

        // Start UDP server for low-latency input (same port)
        udpThread = new Thread(this::runUdpServer);
        udpThread.setName("UDPServer");
        udpThread.setDaemon(true);
        udpThread.start();

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
            case "ping":
                // Reply immediately so client can measure round-trip time (RTT)
                JsonObject pong = new JsonObject();
                pong.addProperty("type", "pong");
                if (message.has("client_time_ms")) {
                    pong.add("client_time_ms", message.get("client_time_ms"));
                }
                pong.addProperty("server_time_ms", System.currentTimeMillis());
                sendToClient(client, pong.toString());
                break;
            default:
                Logger.debug("Unknown message type: " + type);
        }
    }

    private void handlePlayerJoin(GameClient client, JsonObject message) {
        String username = message.get("username").getAsString();
        String password = message.has("password") ? message.get("password").getAsString() : "pass";

        // Get safe zone center from loaded map
        Tilemap tilemap = com.vampireraiders.game.GameWorld.getTilemap();
        float[] safeZoneCenter = tilemap.getSafeZoneCenter();
        float safeZoneCenterX = safeZoneCenter[0];
        float safeZoneCenterY = safeZoneCenter[1];
        
        // Determine spawn position based on player state
        float spawnX = safeZoneCenterX;
        float spawnY = safeZoneCenterY;
        boolean isNewPlayer = false;
        
        // Always create player with current peer ID
        Player player = new Player(client.getPeerId(), username, spawnX, spawnY);
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

                // Determine spawn position: safe zone if dead, last position if alive
                if (player.getHealth() <= 0) {
                    // Player was dead, respawn at safe zone with full health
                    player.setHealth(player.getMaxHealth());
                    player.setPosition(safeZoneCenterX, safeZoneCenterY);
                    Logger.info("Dead player respawned at safe zone: " + username);
                } else {
                    // Player was alive, spawn at last saved position
                    player.setPosition(dbPlayer.getX(), dbPlayer.getY());
                    Logger.info("Returning player spawned at last position: " + username + " (" + dbPlayer.getX() + ", " + dbPlayer.getY() + ")");
                }
                
                Logger.info("Existing player found: " + username + " (dbId=" + databaseId + ") - Level: " + player.getLevel() + ", XP: " + player.getXP());
            }
        } else {
            // Create new player in database at safe zone
            Player newDbPlayer = PlayerRepository.createNewPlayer(username, password);
            if (newDbPlayer != null) {
                databaseId = newDbPlayer.getDatabaseId();
                player.setDatabaseId(databaseId);
                // New players spawn at safe zone (already set above)
                player.setPosition(safeZoneCenterX, safeZoneCenterY);
                isNewPlayer = true;
            } else {
                Logger.error("Failed to create new player " + username);
                return;
            }
            Logger.info("New player created at safe zone: " + username + " (dbId=" + databaseId + ")");
        }

        // Update position for spawn and mark authenticated
        player.setInputDirection(0, 0);
        client.setPlayer(player);
        client.setAuthenticated(true);
        
        // Add player to game world
        gameWorld.getState().addPlayer(client.getPeerId(), player);
        
        Logger.info("Player joined: " + username + " (PeerID: " + client.getPeerId() + ", dbId: " + databaseId + ") - Level: " + player.getLevel() + ", XP: " + player.getXP());

        // Send acknowledgment back
        JsonObject ack = new JsonObject();
        ack.addProperty("type", "player_joined");
        ack.addProperty("peer_id", client.getPeerId());
        ack.addProperty("username", username);
        ack.addProperty("db_id", databaseId);
        ack.addProperty("level", player.getLevel());
        ack.addProperty("xp", player.getXP());
        // Issue a per-session UDP token for securing UDP messages
        String udpToken = java.util.UUID.randomUUID().toString();
        udpTokens.put(client.getPeerId(), udpToken);
        ack.addProperty("udp_token", udpToken);
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
        
        // Get item template info to check if stackable
        int itemTemplateId = item.getItemTemplateId();
        var itemTemplate = ItemTemplateRepository.getItemTemplate(itemTemplateId);
        boolean isStackable = itemTemplate != null && itemTemplate.isStackable();
        Logger.info("PICKUP: Item template " + itemTemplateId + " is stackable: " + isStackable);
        
        // For stackable items, check if we already have this item type
        if (isStackable) {
            Long existingInventoryId = InventoryRepository.findExistingStackableItemTemplate(playerId, itemTemplateId);
            if (existingInventoryId != null) {
                Logger.info("PICKUP: Found existing stackable item, incrementing quantity for inventory_id=" + existingInventoryId);
                InventoryRepository.incrementItemQuantity(existingInventoryId);
                // Delete this world item since we're stacking it (don't need duplicate world_item rows)
                WorldItemRepository.deleteWorldItem(worldItemId);
                gameWorld.getState().removeWorldItem(item);
                Logger.info("PICKUP: Item stacked and deleted from world_items. Pickup complete for item " + worldItemId);
                return;
            }
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
            obj.addProperty("quantity", ((Number) row.get("quantity")).intValue());
            obj.addProperty("slot_x", ((Number) row.get("slot_x")).intValue());
            obj.addProperty("slot_y", ((Number) row.get("slot_y")).intValue());
            arr.add(obj);
            Logger.info("  - Item: " + row.get("name") + " at slot (" + row.get("slot_x") + "," + row.get("slot_y") + "), quantity: " + row.get("quantity"));
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
        
        // Get the quantity before deleting
        int playerId = player.getDatabaseId() > 0 ? player.getDatabaseId() : player.getPeerId();
        var inventoryItems = InventoryRepository.getInventoryForPlayer(playerId);
        int quantity = 1;
        for (var item : inventoryItems) {
            if (((Number) item.get("inventory_id")).longValue() == inventoryId) {
                quantity = ((Number) item.get("quantity")).intValue();
                break;
            }
        }
        
        Logger.info("DROP: Dropping inventory_id=" + inventoryId + " with quantity=" + quantity);
        
        if (quantity > 1) {
            // For stacked items, only drop 1 and decrement the stack
            InventoryRepository.decrementItemQuantity(inventoryId);
            Logger.info("DROP: Decremented quantity, " + (quantity - 1) + " items remain in inventory");
            
            // Create a new world item for the dropped item
            int templateId = -1;
            var info = WorldItemRepository.getWorldItemInfo(worldItemId);
            if (info != null) {
                templateId = ((Number) info.get("item_template_id")).intValue();
                String name = (String) info.get("name");
                long newWorldItemId = WorldItemRepository.createWorldItemAndGetId(templateId, player.getX(), player.getY());
                if (newWorldItemId > 0) {
                    WorldItem wi = new WorldItem(newWorldItemId, templateId, player.getX(), player.getY(), null);
                    wi.setTemplateName(name);
                    gameWorld.getState().addWorldItem(wi);
                    Logger.info("DROP: Created new world item " + newWorldItemId + " for dropped item");
                }
            }
        } else {
            // For non-stacked items or last item in stack, delete from inventory and unclaim
            InventoryRepository.deleteInventoryItem(inventoryId);
            boolean ok = WorldItemRepository.unclaimWorldItem(worldItemId, player.getX(), player.getY());
            if (!ok) return;
            
            var info = WorldItemRepository.getWorldItemInfo(worldItemId);
            if (info != null) {
                int templateId = ((Number) info.get("item_template_id")).intValue();
                String name = (String) info.get("name");
                WorldItem wi = new WorldItem(worldItemId, templateId, player.getX(), player.getY(), null);
                wi.setTemplateName(name);
                gameWorld.getState().addWorldItem(wi);
            }
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
                // Refresh player's equipped items cache
                player.refreshEquippedItemsCache();
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
                // Refresh player's equipped items cache
                player.refreshEquippedItemsCache();
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
                    clients.remove(peerId);
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
            if (udpSocket != null && !udpSocket.isClosed()) {
                udpSocket.close();
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

    // =========================
    // UDP SERVER (INPUT CHANNEL)
    // =========================
    private void runUdpServer() {
        try {
            udpSocket = new DatagramSocket(port);
            Logger.info("UDP Server started on port " + port);

            byte[] buffer = new byte[2048];
            while (running) {
                DatagramPacket packet = new DatagramPacket(buffer, buffer.length);
                try {
                    udpSocket.receive(packet);
                } catch (IOException se) {
                    if (!running) break; // socket closed during stop()
                    Logger.error("UDP receive error: " + se.getMessage());
                    continue;
                }

                String data = new String(packet.getData(), 0, packet.getLength(), StandardCharsets.UTF_8).trim();
                if (data.isEmpty()) continue;

                try {
                    JsonObject message = JsonParser.parseString(data).getAsJsonObject();
                    String type = message.has("type") ? message.get("type").getAsString() : null;
                    if (type == null) continue;

                    switch (type) {
                        case "register_udp": {
                            if (!message.has("peer_id") || !message.has("token") || !message.has("seq") || !message.has("hmac")) break;
                            int pid = message.get("peer_id").getAsInt();
                            String token = message.get("token").getAsString();
                            String expected = udpTokens.get(pid);
                            if (expected == null || !expected.equals(token)) {
                                Logger.debug("UDP register rejected for peer " + pid + ": invalid token");
                                break;
                            }
                            long seq = message.get("seq").getAsLong();
                            String hmac = message.get("hmac").getAsString();
                            if (!validateHmac(expected, type, pid, null, null, seq, hmac)) {
                                Logger.debug("UDP register rejected for peer " + pid + ": bad hmac");
                                break;
                            }
                            if (isReplay(pid, seq)) {
                                Logger.debug("UDP register replay detected for peer " + pid + " seq=" + seq);
                                break;
                            }
                            InetSocketAddress addr = new InetSocketAddress(packet.getAddress(), packet.getPort());
                            udpClients.put(pid, addr);
                            udpBuckets.put(pid, new TokenBucket(UDP_BUCKET_CAPACITY, UDP_INPUT_RATE));
                            Logger.info("UDP registered for peer " + pid + " @ " + addr);
                            break;
                        }
                        case "player_input": {
                            if (!message.has("peer_id") || !message.has("dir_x") || !message.has("dir_y") || !message.has("token") || !message.has("seq") || !message.has("hmac")) break;
                            int pid = message.get("peer_id").getAsInt();
                            String token = message.get("token").getAsString();
                            String expected = udpTokens.get(pid);
                            if (expected == null || !expected.equals(token)) {
                                Logger.debug("UDP input rejected for peer " + pid + ": invalid token");
                                break;
                            }
                            long seq = message.get("seq").getAsLong();
                            String hmac = message.get("hmac").getAsString();
                            Integer dx_i = message.has("dx_i") ? message.get("dx_i").getAsInt() : null;
                            Integer dy_i = message.has("dy_i") ? message.get("dy_i").getAsInt() : null;
                            if (!validateHmac(expected, type, pid, dx_i, dy_i, seq, hmac)) {
                                Logger.debug("UDP input rejected for peer " + pid + ": bad hmac");
                                break;
                            }
                            if (isReplay(pid, seq)) {
                                Logger.debug("UDP input replay detected for peer " + pid + " seq=" + seq);
                                break;
                            }

                            // Rate limit
                            TokenBucket bucket = udpBuckets.computeIfAbsent(pid, k -> new TokenBucket(UDP_BUCKET_CAPACITY, UDP_INPUT_RATE));
                            if (!bucket.tryConsume()) {
                                Logger.debug("UDP input rate limited for peer " + pid);
                                break;
                            }

                            float dx = message.get("dir_x").getAsFloat();
                            float dy = message.get("dir_y").getAsFloat();

                            // Sanity checks: clamp vector length to <= 1 and ignore NaNs/Infs
                            if (!Float.isFinite(dx) || !Float.isFinite(dy)) {
                                break;
                            }
                            float len = (float)Math.sqrt(dx * dx + dy * dy);
                            if (len > 1.0f && len > 0.0f) {
                                dx /= len;
                                dy /= len;
                            }

                            GameClient client = clients.get(pid);
                            if (client != null && client.getPlayer() != null) {
                                client.getPlayer().setInputDirection(dx, dy);
                                client.updateHeartbeat();
                                notifyClientInput(pid, "move", dx, dy);
                            }
                            break;
                        }
                        default:
                            // Ignore other UDP message types for now
                            break;
                    }
                } catch (Exception ex) {
                    Logger.debug("Invalid UDP message: " + ex.getMessage());
                }
            }
        } catch (IOException e) {
            if (running) {
                Logger.error("Failed to start UDP server on port " + port + ": " + e.getMessage());
            }
        }
    }

    private boolean isReplay(int peerId, long seq) {
        Long last = udpLastSeq.get(peerId);
        if (last != null && seq <= last) {
            return true;
        }
        udpLastSeq.put(peerId, seq);
        return false;
    }

    private boolean validateHmac(String token, String type, int peerId, Integer dx_i, Integer dy_i, long seq, String providedHex) {
        try {
            StringBuilder sb = new StringBuilder();
            sb.append(type).append('|').append(peerId).append('|').append(seq);
            if (dx_i != null && dy_i != null) {
                sb.append('|').append(dx_i).append('|').append(dy_i);
            }
            String data = sb.toString();
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(token.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] out = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            String expectedHex = bytesToHex(out);
            return expectedHex.equalsIgnoreCase(providedHex);
        } catch (Exception e) {
            Logger.error("HMAC validation error", e);
            return false;
        }
    }

    private static String bytesToHex(byte[] bytes) {
        char[] hexArray = "0123456789abcdef".toCharArray();
        char[] hexChars = new char[bytes.length * 2];
        for (int j = 0; j < bytes.length; j++) {
            int v = bytes[j] & 0xFF;
            hexChars[j * 2] = hexArray[v >>> 4];
            hexChars[j * 2 + 1] = hexArray[v & 0x0F];
        }
        return new String(hexChars);
    }

    private static class TokenBucket {
        private final int capacity;
        private final int ratePerSec;
        private double tokens;
        private long lastRefillNanos;

        TokenBucket(int capacity, int ratePerSec) {
            this.capacity = capacity;
            this.ratePerSec = ratePerSec;
            this.tokens = capacity;
            this.lastRefillNanos = System.nanoTime();
        }

        synchronized boolean tryConsume() {
            refill();
            if (tokens >= 1.0) {
                tokens -= 1.0;
                return true;
            }
            return false;
        }

        private void refill() {
            long now = System.nanoTime();
            double elapsedSec = (now - lastRefillNanos) / 1_000_000_000.0;
            if (elapsedSec > 0) {
                tokens = Math.min(capacity, tokens + elapsedSec * ratePerSec);
                lastRefillNanos = now;
            }
        }
    }
}
