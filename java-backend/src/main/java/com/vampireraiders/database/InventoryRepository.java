package com.vampireraiders.database;

import com.vampireraiders.util.Logger;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.HashMap;

public class InventoryRepository {

    public static boolean addInventoryItem(int playerId, long worldItemId, int slotX, int slotY) {
        String sql = "INSERT INTO inventory (player_id, world_item_id, slot_x, slot_y) VALUES (?, ?, ?, ?)";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, playerId);
            stmt.setLong(2, worldItemId);
            stmt.setInt(3, slotX);
            stmt.setInt(4, slotY);
            stmt.executeUpdate();
            return true;
        } catch (SQLException e) {
            Logger.error("Failed to add inventory item: " + e.getMessage());
            return false;
        }
    }

    public static List<Map<String, Object>> getInventoryForPlayer(int playerId) {
        String sql = "SELECT inv.id AS inventory_id, inv.slot_x, inv.slot_y, " +
                "wi.id AS world_item_id, wi.item_template_id, it.name, it.type, it.damage, it.defense, it.rarity, it.stackable " +
                "FROM inventory inv " +
                "JOIN world_items wi ON inv.world_item_id = wi.id " +
                "JOIN item_templates it ON wi.item_template_id = it.id " +
                "WHERE inv.player_id = ?";

        List<Map<String, Object>> items = new ArrayList<>();
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, playerId);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new HashMap<>();
                    row.put("inventory_id", rs.getLong("inventory_id"));
                    row.put("slot_x", rs.getInt("slot_x"));
                    row.put("slot_y", rs.getInt("slot_y"));
                    row.put("world_item_id", rs.getLong("world_item_id"));
                    row.put("item_template_id", rs.getInt("item_template_id"));
                    row.put("name", rs.getString("name"));
                    row.put("type", rs.getString("type"));
                    row.put("damage", rs.getInt("damage"));
                    row.put("defense", rs.getInt("defense"));
                    row.put("rarity", rs.getString("rarity"));
                    row.put("stackable", rs.getBoolean("stackable"));
                    items.add(row);
                }
            }
        } catch (SQLException e) {
            Logger.error("Failed to fetch inventory: " + e.getMessage());
        }
        return items;
    }

    public static boolean moveInventoryItem(long inventoryId, int slotX, int slotY) {
        String sql = "UPDATE inventory SET slot_x = ?, slot_y = ? WHERE id = ?";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, slotX);
            stmt.setInt(2, slotY);
            stmt.setLong(3, inventoryId);
            return stmt.executeUpdate() > 0;
        } catch (SQLException e) {
            Logger.error("Failed to move inventory item: " + e.getMessage());
            return false;
        }
    }

    public static boolean deleteInventoryItem(long inventoryId) {
        String sql = "DELETE FROM inventory WHERE id = ?";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setLong(1, inventoryId);
            return stmt.executeUpdate() > 0;
        } catch (SQLException e) {
            Logger.error("Failed to delete inventory item: " + e.getMessage());
            return false;
        }
    }

    public static Long getWorldItemIdForInventory(long inventoryId) {
        String sql = "SELECT world_item_id FROM inventory WHERE id = ?";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setLong(1, inventoryId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return rs.getLong(1);
                }
            }
        } catch (SQLException e) {
            Logger.error("Failed to get world_item_id for inventory: " + e.getMessage());
        }
        return null;
    }

    public static int[] findNextAvailableSlot(int playerId, int gridCols, int gridRows) {
        // Fetch all occupied slots, EXCLUDING equipped items
        // Equipped items remain in inventory table but their slots should be available for new items
        String sql = "SELECT i.slot_x, i.slot_y FROM inventory i " +
                     "LEFT JOIN equipped_items e ON e.player_id = i.player_id " +
                     "AND (e.weapon = i.id OR e.helmet = i.id OR e.armor = i.id OR e.boots = i.id) " +
                     "WHERE i.player_id = ? AND e.player_id IS NULL " +
                     "ORDER BY i.slot_y, i.slot_x";
        java.util.Set<String> occupied = new java.util.HashSet<>();
        
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, playerId);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    int x = rs.getInt("slot_x");
                    int y = rs.getInt("slot_y");
                    occupied.add(x + "," + y);
                }
            }
        } catch (SQLException e) {
            Logger.error("Failed to find available slot: " + e.getMessage());
        }
        
        // Find first empty slot (left-to-right, top-to-bottom)
        for (int y = 0; y < gridRows; y++) {
            for (int x = 0; x < gridCols; x++) {
                if (!occupied.contains(x + "," + y)) {
                    Logger.debug("Next available slot: (" + x + "," + y + ")");
                    return new int[]{x, y};
                }
            }
        }
        
        // Grid full, return (0, 0) as fallback
        Logger.warn("Inventory grid full for player " + playerId);
        return new int[]{0, 0};
    }
}
