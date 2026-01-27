package com.vampireraiders.database;

import com.vampireraiders.game.WorldItem;
import com.vampireraiders.util.Logger;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Map;

public class WorldItemRepository {

    public static WorldItem createWorldItem(int itemTemplateId, float x, float y) {
        String sql = "INSERT INTO world_items (item_template_id, x, y) VALUES (?, ?, ?)";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {

            stmt.setInt(1, itemTemplateId);
            stmt.setFloat(2, x);
            stmt.setFloat(3, y);
            stmt.executeUpdate();

            try (ResultSet rs = stmt.getGeneratedKeys()) {
                if (rs.next()) {
                    long id = rs.getLong(1);
                    Logger.info("Created world item id=" + id + " template=" + itemTemplateId + " at (" + x + "," + y + ")");
                    return new WorldItem(id, itemTemplateId, x, y, null);
                }
            }
        } catch (SQLException e) {
            Logger.error("Failed to create world item: " + e.getMessage());
        }
        return null;
    }

    public static boolean claimWorldItem(long worldItemId, int playerId) {
        String sql = "UPDATE world_items SET claimed_by = ?, claimed_at = NOW() WHERE id = ? AND claimed_by IS NULL";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, playerId);
            stmt.setLong(2, worldItemId);
            int updated = stmt.executeUpdate();
            return updated > 0;
        } catch (SQLException e) {
            Logger.error("Failed to claim world item: " + e.getMessage());
            return false;
        }
    }

    public static boolean unclaimWorldItem(long worldItemId, float x, float y) {
        String sql = "UPDATE world_items SET claimed_by = NULL, claimed_at = NULL, x = ?, y = ? WHERE id = ?";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setFloat(1, x);
            stmt.setFloat(2, y);
            stmt.setLong(3, worldItemId);
            return stmt.executeUpdate() > 0;
        } catch (SQLException e) {
            Logger.error("Failed to unclaim world item: " + e.getMessage());
            return false;
        }
    }

    public static Map<String, Object> getWorldItemInfo(long worldItemId) {
        String sql = "SELECT wi.item_template_id, it.name, it.type FROM world_items wi JOIN item_templates it ON wi.item_template_id = it.id WHERE wi.id = ?";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setLong(1, worldItemId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    var map = new HashMap<String, Object>();
                    map.put("item_template_id", rs.getInt("item_template_id"));
                    map.put("name", rs.getString("name"));
                    map.put("type", rs.getString("type"));
                    return map;
                }
            }
        } catch (SQLException e) {
            Logger.error("Failed to fetch world item info: " + e.getMessage());
        }
        return null;
    }

    public static long createWorldItemAndGetId(int itemTemplateId, float x, float y) {
        String sql = "INSERT INTO world_items (item_template_id, x, y) VALUES (?, ?, ?)";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {

            stmt.setInt(1, itemTemplateId);
            stmt.setFloat(2, x);
            stmt.setFloat(3, y);
            stmt.executeUpdate();

            try (ResultSet rs = stmt.getGeneratedKeys()) {
                if (rs.next()) {
                    long id = rs.getLong(1);
                    Logger.info("Created world item id=" + id + " template=" + itemTemplateId + " at (" + x + "," + y + ")");
                    return id;
                }
            }
        } catch (SQLException e) {
            Logger.error("Failed to create world item: " + e.getMessage());
        }
        return -1;
    }

    public static boolean deleteWorldItem(long worldItemId) {
        String sql = "DELETE FROM world_items WHERE id = ?";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setLong(1, worldItemId);
            int rows = stmt.executeUpdate();
            if (rows > 0) {
                Logger.info("Deleted world item id=" + worldItemId);
                return true;
            }
        } catch (SQLException e) {
            Logger.error("Failed to delete world item: " + e.getMessage());
        }
        return false;
    }
}
