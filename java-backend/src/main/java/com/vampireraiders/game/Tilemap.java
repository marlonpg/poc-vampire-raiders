package com.vampireraiders.game;

import java.util.ArrayList;
import java.util.List;

/**
 * Tile-based map system for managing walkability and zone types
 * Now supports loading from map files instead of procedural generation
 */
public class Tilemap {
    public static final int TILE_SIZE = 64; // pixels per tile
    
    private final TileType[][] tiles;
    private final int mapWidth;
    private final int mapHeight;
    private final List<EliteSpawnPoint> eliteSpawns;
    
    /**
     * Constructor for file-loaded maps
     */
    public Tilemap(TileType[][] tiles, int width, int height) {
        this.tiles = tiles;
        this.mapWidth = width;
        this.mapHeight = height;
        this.eliteSpawns = new ArrayList<>();
        
        // Extract elite spawn positions
        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                TileType type = tiles[x][y];
                if (type.isEliteSpawn()) {
                    float worldX = (x + 0.5f) * TILE_SIZE;
                    float worldY = (y + 0.5f) * TILE_SIZE;
                    eliteSpawns.add(new EliteSpawnPoint(type.getEliteId(), worldX, worldY));
                }
            }
        }
    }
    
    public int getMapWidth() {
        return mapWidth;
    }
    
    public int getMapHeight() {
        return mapHeight;
    }
    
    public List<EliteSpawnPoint> getEliteSpawns() {
        return eliteSpawns;
    }
    
    /**
     * Get tile type at world position (in pixels)
     */
    public TileType getTileAt(float worldX, float worldY) {
        int gridX = (int) (worldX / TILE_SIZE);
        int gridY = (int) (worldY / TILE_SIZE);
        
        if (gridX < 0 || gridX >= mapWidth || gridY < 0 || gridY >= mapHeight) {
            return TileType.BLOCKED; // Out of bounds = blocked
        }
        
        return tiles[gridX][gridY];
    }
    
    /**
     * Check if a world position is walkable for players
     */
    public boolean isWalkable(float worldX, float worldY) {
        TileType type = getTileAt(worldX, worldY);
        return type.isPlayerWalkable();
    }
    
    /**
     * Check if a world position is walkable for enemies
     */
    public boolean isEnemyWalkable(float worldX, float worldY) {
        TileType type = getTileAt(worldX, worldY);
        return type.isEnemyWalkable();
    }
    
    /**
     * Check if position is in safe zone
     */
    public boolean isInSafeZone(float worldX, float worldY) {
        TileType type = getTileAt(worldX, worldY);
        return type.isSafeZone();
    }
    
    /**
     * Check if position is in hunting zone (any PVE area where enemies can be)
     */
    public boolean isInHuntingZone(float worldX, float worldY) {
        TileType type = getTileAt(worldX, worldY);
        return type.isEnemyWalkable() && !type.isSafeZone();
    }
    
    /**
     * Get spawn level for a position (null if not a spawn zone)
     */
    public Integer getSpawnLevel(float worldX, float worldY) {
        TileType type = getTileAt(worldX, worldY);
        return type.getSpawnLevel();
    }
    
    /**
     * Check if position is an elite spawn point
     */
    public boolean isEliteSpawn(float worldX, float worldY) {
        TileType type = getTileAt(worldX, worldY);
        return type.isEliteSpawn();
    }
    
    /**
     * Get the center of the safe zone
     */
    public float[] getSafeZoneCenter() {
        // Find center of all safe zone tiles
        int count = 0;
        float sumX = 0, sumY = 0;
        
        for (int x = 0; x < mapWidth; x++) {
            for (int y = 0; y < mapHeight; y++) {
                if (tiles[x][y].isSafeZone()) {
                    sumX += (x + 0.5f) * TILE_SIZE;
                    sumY += (y + 0.5f) * TILE_SIZE;
                    count++;
                }
            }
        }
        
        if (count == 0) {
            // Fallback to map center
            return new float[] {
                (mapWidth * TILE_SIZE) / 2.0f,
                (mapHeight * TILE_SIZE) / 2.0f
            };
        }
        
        return new float[] { sumX / count, sumY / count };
    }
    
    /**
     * Get all tiles of a specific type
     */
    public List<TilePosition> getTilesOfType(TileType targetType) {
        List<TilePosition> positions = new ArrayList<>();
        for (int x = 0; x < mapWidth; x++) {
            for (int y = 0; y < mapHeight; y++) {
                if (tiles[x][y] == targetType) {
                    float worldX = (x + 0.5f) * TILE_SIZE;
                    float worldY = (y + 0.5f) * TILE_SIZE;
                    positions.add(new TilePosition(x, y, worldX, worldY));
                }
            }
        }
        return positions;
    }
    
    /**
     * Get all spawn zones of a specific level
     */
    public List<TilePosition> getSpawnZones(int level) {
        List<TilePosition> positions = new ArrayList<>();
        for (int x = 0; x < mapWidth; x++) {
            for (int y = 0; y < mapHeight; y++) {
                TileType type = tiles[x][y];
                if (type.getSpawnLevel() != null && type.getSpawnLevel() == level) {
                    float worldX = (x + 0.5f) * TILE_SIZE;
                    float worldY = (y + 0.5f) * TILE_SIZE;
                    positions.add(new TilePosition(x, y, worldX, worldY));
                }
            }
        }
        return positions;
    }
    
    /**
     * Elite spawn point data
     */
    public static class EliteSpawnPoint {
        public final int eliteId;
        public final float x;
        public final float y;
        
        public EliteSpawnPoint(int eliteId, float x, float y) {
            this.eliteId = eliteId;
            this.x = x;
            this.y = y;
        }
    }
    
    /**
     * Tile position data
     */
    public static class TilePosition {
        public final int gridX;
        public final int gridY;
        public final float worldX;
        public final float worldY;
        
        public TilePosition(int gridX, int gridY, float worldX, float worldY) {
            this.gridX = gridX;
            this.gridY = gridY;
            this.worldX = worldX;
            this.worldY = worldY;
        }
    }
    
    /**
     * Get raw tile grid (for debugging/visualization)
     */
    public TileType[][] getTiles() {
        return tiles;
    }
}
