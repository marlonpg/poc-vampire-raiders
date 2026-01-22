package com.vampireraiders.database;

import com.vampireraiders.util.Logger;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

public class EquippedItemRepository {

    public static boolean equipItem(int playerId, long inventoryId, String slotType) {
        String sql = "INSERT INTO equipped_items (player_id, " + slotType + ") " +
                "VALUES (?, ?) " +
                "ON DUPLICATE KEY UPDATE " + slotType + " = ?";
        
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, playerId);
            stmt.setLong(2, inventoryId);
            stmt.setLong(3, inventoryId);
            stmt.executeUpdate();
            return true;
        } catch (SQLException e) {
            Logger.error("Failed to equip item: " + e.getMessage());
            return false;
        }
    }

    public static boolean unequipItem(int playerId, String slotType) {
        String sql = "UPDATE equipped_items SET " + slotType + " = NULL WHERE player_id = ?";
        
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, playerId);
            stmt.executeUpdate();
            return true;
        } catch (SQLException e) {
            Logger.error("Failed to unequip item: " + e.getMessage());
            return false;
        }
    }

    public static Map<String, Map<String, Object>> getEquippedItems(int playerId) {
        String sql = "SELECT e.weapon, e.helmet, e.armor, e.boots, " +
                "inv.id as inv_id, inv.slot_x, inv.slot_y, " +
                "wi.id as world_item_id, wi.item_template_id, " +
                "it.name, it.type, it.damage, it.defense, it.attack_speed, it.attack_range, it.attack_type, it.rarity, it.stackable " +
                "FROM equipped_items e " +
                "LEFT JOIN inventory inv ON (e.weapon = inv.id OR e.helmet = inv.id OR e.armor = inv.id OR e.boots = inv.id) " +
                "LEFT JOIN world_items wi ON inv.world_item_id = wi.id " +
                "LEFT JOIN item_templates it ON wi.item_template_id = it.id " +
                "WHERE e.player_id = ?";

        Map<String, Map<String, Object>> equipped = new HashMap<>();
        
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, playerId);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    long weaponId = rs.getLong("weapon");
                    long helmetId = rs.getLong("helmet");
                    long armorId = rs.getLong("armor");
                    long bootsId = rs.getLong("boots");
                    
                    // Check which slot has the item we're looking at
                    long invId = rs.getLong("inv_id");
                    String slotType = null;
                    
                    if (weaponId > 0 && weaponId == invId) slotType = "weapon";
                    else if (helmetId > 0 && helmetId == invId) slotType = "helmet";
                    else if (armorId > 0 && armorId == invId) slotType = "armor";
                    else if (bootsId > 0 && bootsId == invId) slotType = "boots";
                    
                    if (slotType != null && invId > 0) {
                        Map<String, Object> item = new HashMap<>();
                        item.put("inventory_id", invId);
                        item.put("world_item_id", rs.getLong("world_item_id"));
                        item.put("item_template_id", rs.getInt("item_template_id"));
                        item.put("name", rs.getString("name"));
                        item.put("type", rs.getString("type"));
                        item.put("damage", rs.getInt("damage"));
                        item.put("defense", rs.getInt("defense"));
                        item.put("attack_speed", rs.getFloat("attack_speed"));
                        item.put("attack_range", rs.getFloat("attack_range"));
                        item.put("attack_type", rs.getString("attack_type"));
                        item.put("rarity", rs.getString("rarity"));
                        item.put("stackable", rs.getBoolean("stackable"));
                        
                        equipped.put(slotType, item);
                    }
                }
            }
        } catch (SQLException e) {
            Logger.error("Failed to get equipped items: " + e.getMessage());
        }
        
        return equipped;
    }

    public static Map<String, Object> getEquippedWeapon(int playerId) {
        Map<String, Map<String, Object>> equipped = getEquippedItems(playerId);
        return equipped.get("weapon");
    }
}
