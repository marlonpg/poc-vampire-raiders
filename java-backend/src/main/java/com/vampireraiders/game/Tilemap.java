package com.vampireraiders.game;

/**
 * Tile-based map system for managing walkability and zone types
 */
public class Tilemap {
    public static final int TILE_SIZE = 64; // pixels per tile
    public static final int MAP_WIDTH = 250; // tiles
    public static final int MAP_HEIGHT = 250; // tiles
    
    // Tile types
    public static final int TILE_SAFE_ZONE = 1;      // Green safe zone - walkable, no damage
    public static final int TILE_MOAT = 2;           // Blue moat - not walkable, blocked
    public static final int TILE_BRIDGE = 3;         // Green bridge - walkable, crosses moat
    public static final int TILE_HUNTING = 4;        // Red hunting ground - walkable, enemies spawn
    
    private int[][] tiles;
    
    public Tilemap() {
        tiles = new int[MAP_WIDTH][MAP_HEIGHT];
        generateMap();
    }
    
    /**
     * Generate the map layout with safe zone, moat, bridges, and hunting grounds
     */
    private void generateMap() {
        // Initialize everything as hunting zone
        for (int x = 0; x < MAP_WIDTH; x++) {
            for (int y = 0; y < MAP_HEIGHT; y++) {
                tiles[x][y] = TILE_HUNTING;
            }
        }
        
        // Center of map
        int centerX = MAP_WIDTH / 2;
        int centerY = MAP_HEIGHT / 2;
        
        // Safe zone: 25x25 grids at center
        int safeZoneSize = 25;
        int safeHalf = safeZoneSize / 2;
        for (int x = centerX - safeHalf; x < centerX + safeHalf; x++) {
            for (int y = centerY - safeHalf; y < centerY + safeHalf; y++) {
                if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
                    tiles[x][y] = TILE_SAFE_ZONE;
                }
            }
        }
        
        // Moat: 10 grids wide ring around safe zone
        int moatWidth = 10;
        int moatInner = safeHalf;
        int moatOuter = safeHalf + moatWidth;
        
        for (int x = 0; x < MAP_WIDTH; x++) {
            for (int y = 0; y < MAP_HEIGHT; y++) {
                if (tiles[x][y] == TILE_HUNTING) { // Only modify hunting tiles
                    int dx = Math.abs(x - centerX);
                    int dy = Math.abs(y - centerY);
                    
                    // Check if in rectangular moat ring (diamond shape for simplicity)
                    boolean inMoat = (dx > moatInner || dy > moatInner) && 
                                     (dx < moatOuter && dy < moatOuter);
                    
                    if (inMoat) {
                        tiles[x][y] = TILE_MOAT;
                    }
                }
            }
        }
        
        // North-South bridges: vertical corridors 6 tiles wide
        int bridgeWidth = 6;
        int bridgeHalf = bridgeWidth / 2;
        
        // North bridge
        for (int x = centerX - bridgeHalf; x < centerX + bridgeHalf; x++) {
            for (int y = centerY - moatOuter; y < centerY - moatInner; y++) {
                if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
                    tiles[x][y] = TILE_BRIDGE;
                }
            }
        }
        
        // South bridge
        for (int x = centerX - bridgeHalf; x < centerX + bridgeHalf; x++) {
            for (int y = centerY + moatInner; y < centerY + moatOuter; y++) {
                if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
                    tiles[x][y] = TILE_BRIDGE;
                }
            }
        }
        
        // East-West bridges: horizontal corridors 6 tiles wide
        
        // West bridge
        for (int x = centerX - moatOuter; x < centerX - moatInner; x++) {
            for (int y = centerY - bridgeHalf; y < centerY + bridgeHalf; y++) {
                if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
                    tiles[x][y] = TILE_BRIDGE;
                }
            }
        }
        
        // East bridge
        for (int x = centerX + moatInner; x < centerX + moatOuter; x++) {
            for (int y = centerY - bridgeHalf; y < centerY + bridgeHalf; y++) {
                if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
                    tiles[x][y] = TILE_BRIDGE;
                }
            }
        }
    }
    
    /**
     * Get tile type at world position (in pixels)
     */
    public int getTileAt(float worldX, float worldY) {
        int gridX = (int) (worldX / TILE_SIZE);
        int gridY = (int) (worldY / TILE_SIZE);
        
        if (gridX < 0 || gridX >= MAP_WIDTH || gridY < 0 || gridY >= MAP_HEIGHT) {
            return TILE_MOAT; // Out of bounds = blocked
        }
        
        return tiles[gridX][gridY];
    }
    
    /**
     * Check if a world position is walkable
     */
    public boolean isWalkable(float worldX, float worldY) {
        int tileType = getTileAt(worldX, worldY);
        return tileType != TILE_MOAT; // Moat is the only blocked tile
    }
    
    /**
     * Check if position is in safe zone
     */
    public boolean isInSafeZone(float worldX, float worldY) {
        return getTileAt(worldX, worldY) == TILE_SAFE_ZONE;
    }
    
    /**
     * Check if position is in hunting zone (where enemies spawn)
     */
    public boolean isInHuntingZone(float worldX, float worldY) {
        return getTileAt(worldX, worldY) == TILE_HUNTING;
    }
    
    /**
     * Get tile type name for debugging
     */
    public static String getTileName(int tileType) {
        switch (tileType) {
            case TILE_SAFE_ZONE: return "SAFE_ZONE";
            case TILE_MOAT: return "MOAT";
            case TILE_BRIDGE: return "BRIDGE";
            case TILE_HUNTING: return "HUNTING";
            default: return "UNKNOWN";
        }
    }
    
    /**
     * Get raw tile grid (for debugging/visualization)
     */
    public int[][] getTiles() {
        return tiles;
    }
}
