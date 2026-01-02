package com.vampireraiders.game;

/**
 * Tile types for map system
 */
public enum TileType {
    // Blocked area - nothing can walk
    BLOCKED("BLK", false, false, false, null, false),
    
    // Safe zone - players only
    SAFE_ZONE("SAF", true, false, true, null, false),
    
    // PVE zone - both can walk, no specific spawn
    PVE("PVE", true, true, false, null, false),
    
    // Elite spawn zones
    ELITE_1("EL1", true, true, false, null, true),
    ELITE_2("EL2", true, true, false, null, true),
    ELITE_3("EL3", true, true, false, null, true),
    ELITE_4("EL4", true, true, false, null, true),
    
    // Monster spawn zones by level
    SPAWN_LEVEL_1("PV1", true, true, false, 1, false),
    SPAWN_LEVEL_2("PV2", true, true, false, 2, false),
    SPAWN_LEVEL_3("PV3", true, true, false, 3, false),
    SPAWN_LEVEL_4("PV4", true, true, false, 4, false);
    
    private final String code;
    private final boolean playerWalkable;
    private final boolean enemyWalkable;
    private final boolean safeZone;
    private final Integer spawnLevel;
    private final boolean eliteSpawn;
    
    TileType(String code, boolean playerWalkable, boolean enemyWalkable, 
             boolean safeZone, Integer spawnLevel, boolean eliteSpawn) {
        this.code = code;
        this.playerWalkable = playerWalkable;
        this.enemyWalkable = enemyWalkable;
        this.safeZone = safeZone;
        this.spawnLevel = spawnLevel;
        this.eliteSpawn = eliteSpawn;
    }
    
    public String getCode() {
        return code;
    }
    
    public boolean isPlayerWalkable() {
        return playerWalkable;
    }
    
    public boolean isEnemyWalkable() {
        return enemyWalkable;
    }
    
    public boolean isSafeZone() {
        return safeZone;
    }
    
    public Integer getSpawnLevel() {
        return spawnLevel;
    }
    
    public boolean isEliteSpawn() {
        return eliteSpawn;
    }
    
    public int getEliteId() {
        if (!eliteSpawn) return -1;
        return Integer.parseInt(code.substring(2)); // Extract number from EL1, EL2, etc.
    }
    
    /**
     * Parse tile type from code string (e.g., "BLK", "SAF", "PV1")
     */
    public static TileType fromCode(String code) {
        for (TileType type : values()) {
            if (type.code.equals(code)) {
                return type;
            }
        }
        throw new IllegalArgumentException("Unknown tile code: " + code);
    }
}
