package com.vampireraiders.database;

import com.vampireraiders.util.Logger;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class ItemModRepository {

    public static boolean hasModsForWorldItem(long worldItemId) {
        String sql = "SELECT 1 FROM item_mods WHERE world_item_id = ? LIMIT 1";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setLong(1, worldItemId);
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next();
            }
        } catch (SQLException e) {
            Logger.error("Failed to check item mods: " + e.getMessage());
        }
        return false;
    }

    public static List<Map<String, Object>> getModsForWorldItem(long worldItemId) {
        String sql = "SELECT mt.mod_type, mt.mod_value, mt.mod_name " +
                "FROM item_mods im " +
                "JOIN mod_templates mt ON im.mod_template_id = mt.id " +
                "WHERE im.world_item_id = ? " +
                "ORDER BY mt.mod_type, mt.mod_value";

        List<Map<String, Object>> mods = new ArrayList<>();
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setLong(1, worldItemId);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new HashMap<>();
                    row.put("mod_type", rs.getString("mod_type"));
                    row.put("mod_value", rs.getInt("mod_value"));
                    row.put("mod_name", rs.getString("mod_name"));
                    mods.add(row);
                }
            }
        } catch (SQLException e) {
            Logger.error("Failed to fetch item mods: " + e.getMessage());
        }

        return mods;
    }

    public static Integer getModTemplateId(String modType, int modValue) {
        String sql = "SELECT id FROM mod_templates WHERE mod_type = ? AND mod_value = ? LIMIT 1";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, modType);
            stmt.setInt(2, modValue);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        } catch (SQLException e) {
            Logger.error("Failed to get mod template id: " + e.getMessage());
        }
        return null;
    }

    public static int getMaxModValue(String modType) {
        String sql = "SELECT COALESCE(MAX(mod_value), 0) AS max_value FROM mod_templates WHERE mod_type = ?";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, modType);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("max_value");
                }
            }
        } catch (SQLException e) {
            Logger.error("Failed to get max mod value: " + e.getMessage());
        }
        return 0;
    }

    /**
     * Returns the current mod_value for the given world item and mod type, or 0 if none.
     */
    public static int getModValueForWorldItem(long worldItemId, String modType) {
        String sql = "SELECT mt.mod_value " +
                "FROM item_mods im " +
                "JOIN mod_templates mt ON im.mod_template_id = mt.id " +
                "WHERE im.world_item_id = ? AND mt.mod_type = ? " +
                "ORDER BY mt.mod_value DESC LIMIT 1";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setLong(1, worldItemId);
            stmt.setString(2, modType);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("mod_value");
                }
            }
        } catch (SQLException e) {
            Logger.error("Failed to get item mod value: " + e.getMessage());
        }
        return 0;
    }

    /**
     * Upserts a mod of a given type on a world item by setting it to the given mod template.
     */
    public static boolean upsertWorldItemMod(long worldItemId, String modType, int modTemplateId) {
        // Check if a mod of this type already exists for the world item
        String findSql = "SELECT im.id " +
                "FROM item_mods im " +
                "JOIN mod_templates mt ON im.mod_template_id = mt.id " +
                "WHERE im.world_item_id = ? AND mt.mod_type = ? LIMIT 1";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement findStmt = conn.prepareStatement(findSql)) {
            findStmt.setLong(1, worldItemId);
            findStmt.setString(2, modType);

            Long itemModId = null;
            try (ResultSet rs = findStmt.executeQuery()) {
                if (rs.next()) {
                    itemModId = rs.getLong(1);
                }
            }

            if (itemModId != null) {
                String updateSql = "UPDATE item_mods SET mod_template_id = ? WHERE id = ?";
                try (PreparedStatement updateStmt = conn.prepareStatement(updateSql)) {
                    updateStmt.setInt(1, modTemplateId);
                    updateStmt.setLong(2, itemModId);
                    return updateStmt.executeUpdate() > 0;
                }
            } else {
                String insertSql = "INSERT INTO item_mods (world_item_id, mod_template_id) VALUES (?, ?)";
                try (PreparedStatement insertStmt = conn.prepareStatement(insertSql)) {
                    insertStmt.setLong(1, worldItemId);
                    insertStmt.setInt(2, modTemplateId);
                    return insertStmt.executeUpdate() > 0;
                }
            }

        } catch (SQLException e) {
            Logger.error("Failed to upsert world item mod: " + e.getMessage());
            return false;
        }
    }
}
