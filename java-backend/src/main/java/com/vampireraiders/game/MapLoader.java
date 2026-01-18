package com.vampireraiders.game;

import com.vampireraiders.util.Logger;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;

/**
 * Loads map data from text files
 */
public class MapLoader {
    
    /**
     * Load a map from a resource file
     * @param filename Name of the file in resources folder (e.g., "small-map.txt")
     * @return Loaded Tilemap instance
     */
    public static Tilemap loadMap(String filename) {
        try {
            InputStream stream = MapLoader.class.getClassLoader().getResourceAsStream(filename);
            if (stream == null) {
                throw new RuntimeException("Map file not found: " + filename);
            }
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(stream));
            List<String> lines = new ArrayList<>();
            String line;
            
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (!line.isEmpty()) {
                    lines.add(line);
                }
            }
            reader.close();
            
            if (lines.isEmpty()) {
                throw new RuntimeException("Map file is empty: " + filename);
            }
            
            return parseMap(lines, filename);
            
        } catch (Exception e) {
            Logger.error("Failed to load map file " + filename + ": " + e.getMessage());
            e.printStackTrace();
            throw new RuntimeException("Failed to load map: " + filename, e);
        }
    }
    
    private static Tilemap parseMap(List<String> lines, String filename) {
        int height = lines.size();
        int width = 0;
        
        // Parse tiles and determine width
        List<List<TileType>> rows = new ArrayList<>();
        
        for (String line : lines) {
            List<TileType> row = new ArrayList<>();
            
            // Split by ][, removing leading [ and trailing ]
            String cleaned = line.replaceAll("^\\[|\\]$", "");
            String[] tiles = cleaned.split("\\]\\[");
            
            for (String tileCode : tiles) {
                try {
                    TileType type = TileType.fromCode(tileCode);
                    row.add(type);
                } catch (IllegalArgumentException e) {
                    Logger.error("Unknown tile code '" + tileCode + "' in " + filename);
                    row.add(TileType.BLOCKED); // Default to blocked
                }
            }
            
            if (width == 0) {
                width = row.size();
            } else if (row.size() != width) {
                throw new RuntimeException("Inconsistent row width in map file: " + filename);
            }
            
            rows.add(row);
        }
        
        // Convert to 2D array
        TileType[][] tiles = new TileType[width][height];
        for (int y = 0; y < height; y++) {
            List<TileType> row = rows.get(y);
            for (int x = 0; x < width; x++) {
                tiles[x][y] = row.get(x);
            }
        }
        
        Logger.info("[MAP-LOADING] Loaded map " + filename + " - Size: " + width + "x" + height);
        
        return new Tilemap(tiles, width, height);
    }
}
