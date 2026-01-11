package com.vampireraiders.database;

import com.vampireraiders.game.ItemTemplate;
import com.vampireraiders.util.Logger;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

public class ItemTemplateRepository {
    private static final Random RANDOM = new Random();
    private static volatile List<ItemTemplate> cache = Collections.emptyList();

    public static synchronized void loadTemplates() {
        String sql = "SELECT id, name, type, damage, defense, attack_speed, attack_range, rarity, stackable, description FROM item_templates";
        List<ItemTemplate> templates = new ArrayList<>();

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            while (rs.next()) {
                ItemTemplate template = new ItemTemplate(
                        rs.getInt("id"),
                        rs.getString("name"),
                        rs.getString("type"),
                        rs.getInt("damage"),
                        rs.getInt("defense"),
                        rs.getFloat("attack_speed"),
                        rs.getFloat("attack_range"),
                        rs.getString("rarity"),
                        rs.getBoolean("stackable"),
                        rs.getString("description")
                );
                templates.add(template);
            }
            cache = Collections.unmodifiableList(templates);
            Logger.info("Loaded " + cache.size() + " item templates into cache");
        } catch (SQLException e) {
            Logger.error("Failed to load item templates: " + e.getMessage());
        }
    }

    public static ItemTemplate getRandomTemplate() {
        if (cache.isEmpty()) {
            loadTemplates();
        }
        if (cache.isEmpty()) return null;
        int index = RANDOM.nextInt(cache.size());
        return cache.get(index);
    }

    public static List<ItemTemplate> getCache() {
        if (cache.isEmpty()) {
            loadTemplates();
        }
        return cache;
    }

    public static ItemTemplate getItemTemplate(int templateId) {
        if (cache.isEmpty()) {
            loadTemplates();
        }
        return cache.stream()
                .filter(t -> t.getId() == templateId)
                .findFirst()
                .orElse(null);
    }
}
