package com.vampireraiders.database;

import com.vampireraiders.game.EnemyItem;
import com.vampireraiders.util.Logger;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.*;

public class EnemyItemRepository {
    // Cache: enemyTemplateId -> list of drops with rates
    private static volatile Map<Integer, List<EnemyItem>> cache = Collections.emptyMap();

    public static synchronized void loadCache() {
        String sql = "SELECT id, enemy_template_id, item_template_id, drop_rate FROM enemy_items";
        Map<Integer, List<EnemyItem>> dropMap = new HashMap<>();

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            int count = 0;
            while (rs.next()) {
                EnemyItem item = new EnemyItem(
                        rs.getInt("id"),
                        rs.getInt("enemy_template_id"),
                        rs.getInt("item_template_id"),
                        rs.getDouble("drop_rate")
                );
                
                dropMap.computeIfAbsent(item.getEnemyTemplateId(), k -> new ArrayList<>()).add(item);
                count++;
            }
            
            // Make all lists unmodifiable
            dropMap.replaceAll((k, v) -> Collections.unmodifiableList(v));
            cache = Collections.unmodifiableMap(dropMap);
            
            Logger.info("Loaded " + count + " enemy item drops into cache for " + cache.size() + " enemy types");
        } catch (SQLException e) {
            Logger.error("Failed to load enemy items: " + e.getMessage());
        }
    }

    public static List<EnemyItem> getDropsForEnemy(int enemyTemplateId) {
        if (cache.isEmpty()) {
            loadCache();
        }
        return cache.getOrDefault(enemyTemplateId, Collections.emptyList());
    }

    public static Map<Integer, List<EnemyItem>> getCache() {
        if (cache.isEmpty()) {
            loadCache();
        }
        return cache;
    }
}
