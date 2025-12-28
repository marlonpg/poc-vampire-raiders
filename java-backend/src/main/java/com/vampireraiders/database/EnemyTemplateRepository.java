package com.vampireraiders.database;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.vampireraiders.game.EnemyTemplate;
import com.vampireraiders.util.Logger;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.*;

public class EnemyTemplateRepository {
    private static final Gson GSON = new Gson();
    private static volatile Map<String, EnemyTemplate> cache = Collections.emptyMap();

    public static synchronized void loadTemplates() {
        String sql = "SELECT id, name, level, hp, defense, attack, attack_rate, move_speed, " +
                    "attack_range, experience, drops FROM enemy_templates";
        Map<String, EnemyTemplate> templates = new HashMap<>();

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            while (rs.next()) {
                String dropsJson = rs.getString("drops");
                List<Integer> drops = GSON.fromJson(dropsJson, new TypeToken<List<Integer>>(){}.getType());
                
                EnemyTemplate template = new EnemyTemplate(
                        rs.getInt("id"),
                        rs.getString("name"),
                        rs.getInt("level"),
                        rs.getInt("hp"),
                        rs.getInt("defense"),
                        rs.getInt("attack"),
                        rs.getFloat("attack_rate"),
                        rs.getFloat("move_speed"),
                        rs.getFloat("attack_range"),
                        rs.getInt("experience"),
                        drops != null ? drops : Collections.emptyList()
                );
                templates.put(template.getName(), template);
            }
            cache = Collections.unmodifiableMap(templates);
            Logger.info("Loaded " + cache.size() + " enemy templates into cache");
        } catch (SQLException e) {
            Logger.error("Failed to load enemy templates: " + e.getMessage());
        }
    }

    public static EnemyTemplate getByName(String name) {
        if (cache.isEmpty()) {
            loadTemplates();
        }
        return cache.get(name);
    }

    public static Map<String, EnemyTemplate> getCache() {
        if (cache.isEmpty()) {
            loadTemplates();
        }
        return cache;
    }
}
