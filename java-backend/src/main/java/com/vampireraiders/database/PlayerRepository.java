package com.vampireraiders.database;

import com.vampireraiders.game.Player;
import com.vampireraiders.util.Logger;

import java.sql.*;

public class PlayerRepository {

    /**
     * Save or update a player in the database
     */
    public static void savePlayer(Player player) {
        String sql = "INSERT INTO players (username, password, level, experience, health, max_health, xp) " +
                     "VALUES (?, 'pass', ?, ?, ?, ?, ?) " +
                     "ON DUPLICATE KEY UPDATE level=?, experience=?, health=?, max_health=?, xp=?";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, player.getUsername());
            stmt.setInt(2, player.getLevel());
            stmt.setLong(3, player.getXP());
            stmt.setInt(4, player.getHealth());
            stmt.setInt(5, player.getMaxHealth());
            stmt.setInt(6, player.getXP());

            // ON DUPLICATE KEY UPDATE values
            stmt.setInt(7, player.getLevel());
            stmt.setLong(8, player.getXP());
            stmt.setInt(9, player.getHealth());
            stmt.setInt(10, player.getMaxHealth());
            stmt.setInt(11, player.getXP());

            stmt.executeUpdate();
            Logger.debug("Player " + player.getUsername() + " saved to database");
        } catch (SQLException e) {
            Logger.error("Failed to save player " + player.getUsername() + ": " + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * Load a player from the database by username
     */
    public static Player loadPlayerByUsername(String username) {
        String sql = "SELECT id, username, level, experience, health, max_health, xp FROM players WHERE username = ?";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, username);
            ResultSet rs = stmt.executeQuery();

            if (rs.next()) {
                int databaseId = rs.getInt("id");
                String dbUsername = rs.getString("username");
                int level = rs.getInt("level");
                long experience = rs.getLong("experience");
                int health = rs.getInt("health");
                int maxHealth = rs.getInt("max_health");
                int xp = rs.getInt("xp");

                Player player = new Player(databaseId, dbUsername, 640, 360);
                player.setDatabaseId(databaseId);  // Also set the database ID explicitly
                player.setLevel(level);
                player.setXP(xp);
                player.setHealth(health);
                player.setMaxHealth(maxHealth);

                Logger.info("Loaded player " + username + " from database with ID: " + databaseId);
                return player;
            }
        } catch (SQLException e) {
            Logger.error("Failed to load player " + username + ": " + e.getMessage());
            e.printStackTrace();
        }

        return null;
    }

    /**
     * Check if a player exists
     */
    public static boolean playerExists(String username) {
        String sql = "SELECT id FROM players WHERE username = ?";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, username);
            ResultSet rs = stmt.executeQuery();
            return rs.next();
        } catch (SQLException e) {
            Logger.error("Failed to check player existence: " + e.getMessage());
            e.printStackTrace();
        }

        return false;
    }

    /**
     * Create a new player in the database
     */
    public static Player createNewPlayer(String username, String password) {
        String sql = "INSERT INTO players (username, password, level, experience, health, max_health, xp) " +
                     "VALUES (?, ?, 1, 0, 100, 100, 0)";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {

            stmt.setString(1, username);
            stmt.setString(2, password);
            stmt.executeUpdate();

            ResultSet generatedKeys = stmt.getGeneratedKeys();
            if (generatedKeys.next()) {
                int playerId = generatedKeys.getInt(1);
                Player player = new Player(playerId, username, 640, 360);
                player.setDatabaseId(playerId);  // Set database ID
                Logger.info("Created new player " + username + " in database with ID: " + playerId);
                return player;
            }
        } catch (SQLException e) {
            Logger.error("Failed to create new player " + username + ": " + e.getMessage());
            e.printStackTrace();
        }

        return null;
    }

    /**
     * Validate username and password
     */
    public static boolean validateCredentials(String username, String password) {
        String sql = "SELECT id FROM players WHERE username = ? AND password = ?";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, username);
            stmt.setString(2, password);
            ResultSet rs = stmt.executeQuery();
            return rs.next();
        } catch (SQLException e) {
            Logger.error("Failed to validate credentials: " + e.getMessage());
            e.printStackTrace();
        }

        return false;
    }
}
