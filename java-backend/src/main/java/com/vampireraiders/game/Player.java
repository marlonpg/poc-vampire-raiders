package com.vampireraiders.game;

import com.vampireraiders.database.EquippedItemRepository;
import com.vampireraiders.database.ItemModRepository;
import com.vampireraiders.database.PlayerRepository;
import java.util.Map;

public class Player {
    private final int peerId;
    private int databaseId = -1;  // Loaded from database later
    private final String username;
    private float x;
    private float y;
    private int health;
    private int maxHealth;
    private int xp;
    private int level;
    private float velocityX;
    private float velocityY;
    private float moveSpeed = 100f;  // Default from database
    private long lastUpdateTime;
    private long lastAttackTime = 0;
    private final long baseAttackCooldownMs = 1000;  // Base: 1 attack per second
    
        // Cached equipped weapon stats (to avoid DB queries every attack)
        private float cachedAttackSpeed = 0.5f;
        private float cachedAttackRange = 50.0f;
        private int cachedWeaponDamage = 0;
        private int cachedWeaponLevelMod = 0;
        private String cachedAttackType = null;  // "ranged", "melee", or null

    public Player(int peerId, String username, float x, float y) {
        this.peerId = peerId;
        this.username = username;
        this.x = x;
        this.y = y;
        this.health = 100;
        this.maxHealth = 100;
        this.xp = 0;
        this.level = 1;
        this.velocityX = 0;
        this.velocityY = 0;
        this.lastUpdateTime = System.currentTimeMillis();
    }

    public void update(float deltaTime) {
        x += velocityX * moveSpeed * deltaTime;
        y += velocityY * moveSpeed * deltaTime;
        lastUpdateTime = System.currentTimeMillis();
    }

    public void setInputDirection(float velX, float velY) {
        this.velocityX = velX;
        this.velocityY = velY;
    }

    public void takeDamage(int damage) {
        boolean wasAlive = this.health > 0;
        this.health = Math.max(0, health - damage);
        System.out.println("Player " + username + " took " + damage + " dmg, health=" + health + "/" + maxHealth);
        
        // Save immediately on death to preserve final state
        if (wasAlive && this.health == 0) {
            System.out.println("Player " + username + " died! Saving state...");
            PlayerRepository.savePlayer(this);
        }
    }

    // Removed unused heal() method

    public void gainXP(int amount) {
        int oldXP = this.xp;
        this.xp += amount;
        System.out.println("Player " + username + " gained " + amount + " XP: " + oldXP + " -> " + xp);
        checkLevelUp();
    }

    private void checkLevelUp() {
        int xpRequired = (int) (120.0 * Math.pow(level, 1.5));
        if (xp >= xpRequired) {
            level++;
            maxHealth += 20;
            health = maxHealth;
            xp = 0;
            System.out.println("Player " + username + " leveled up to level " + level + "! Max health: " + maxHealth);
            
            // Save immediately on level up to prevent progress loss
            PlayerRepository.savePlayer(this);
        }
    }

    // Getters
    public int getPeerId() { return peerId; }
    public int getDatabaseId() { return databaseId; }
    public String getUsername() { return username; }
    public float getX() { return x; }
    public float getY() { return y; }
    public int getHealth() { return health; }
    public int getMaxHealth() { return maxHealth; }
    public int getXP() { return xp; }
    public int getLevel() { return level; }
    public float getVelocityX() { return velocityX; }
    public float getVelocityY() { return velocityY; }
    public long getLastUpdateTime() { return lastUpdateTime; }

    // Setters (for loading from database)
    public void setHealth(int h) { this.health = Math.max(0, h); }
    public void setMaxHealth(int mh) { this.maxHealth = mh; }
    public void setLevel(int l) { this.level = l; }
    public void setXP(int x) { this.xp = x; }
    public void setMoveSpeed(float moveSpeed) { this.moveSpeed = moveSpeed; }
    public void setPosition(float x, float y) { this.x = x; this.y = y; }
    public void setDatabaseId(int id) { 
        this.databaseId = id;
        // Load equipped items cache when database ID is set
        refreshEquippedItemsCache();
    }
    
    public float getMoveSpeed() { return moveSpeed; }

    public boolean isAlive() {
        return health > 0;
    }

    public boolean canAttack() {
        long cooldown = getAttackCooldown();
        return System.currentTimeMillis() - lastAttackTime >= cooldown;
    }

    public long getAttackCooldown() {
        // Get equipped weapon's attack speed
        float attackSpeed = getEquippedAttackSpeed();
        // Cooldown = base / attack_speed (higher attack_speed = faster attacks)
        return (long) (baseAttackCooldownMs / attackSpeed);
    }

    public float getEquippedAttackSpeed() {
        return cachedAttackSpeed;
    }

    public float getEquippedAttackRange() {
        return cachedAttackRange;
    }
    
    public int getCachedWeaponDamage() {
        return cachedWeaponDamage;
    }

    public int getCachedWeaponLevelMod() {
        return cachedWeaponLevelMod;
    }
    
    public String getEquippedAttackType() {
        return cachedAttackType;
    }
    
    /**
     * Refreshes the cached equipped weapon stats from the database.
     * Should be called whenever a player equips/unequips items.
     */
    public void refreshEquippedItemsCache() {
        if (databaseId <= 0) {
            return; // No database ID yet, can't load
        }
        
        Map<String, Object> weapon = EquippedItemRepository.getEquippedWeapon(databaseId);
        if (weapon != null) {
            // Extract weapon stats
            if (weapon.containsKey("attack_speed")) {
                cachedAttackSpeed = (Float) weapon.get("attack_speed");
            } else {
                cachedAttackSpeed = 1.0f;
            }
            
            if (weapon.containsKey("attack_range")) {
                cachedAttackRange = (Float) weapon.get("attack_range");
            } else {
                cachedAttackRange = 200.0f;
            }
            
            if (weapon.containsKey("damage")) {
                cachedWeaponDamage = ((Number) weapon.get("damage")).intValue();
            } else {
                cachedWeaponDamage = 0;
            }

            // Cache mods that affect combat.
            // Mods are stored per world item instance (world_item_id).
            if (weapon.containsKey("world_item_id") && weapon.get("world_item_id") instanceof Number) {
                long worldItemId = ((Number) weapon.get("world_item_id")).longValue();
                cachedWeaponLevelMod = ItemModRepository.getModValueForWorldItem(worldItemId, "LEVEL");
            } else {
                cachedWeaponLevelMod = 0;
            }
            
            if (weapon.containsKey("attack_type")) {
                cachedAttackType = (String) weapon.get("attack_type");
            } else {
                cachedAttackType = null;
            }
        } else {
            // No weapon equipped, use defaults
            cachedAttackSpeed = 1.0f;
            cachedAttackRange = 200.0f;
            cachedWeaponDamage = 0;
            cachedWeaponLevelMod = 0;
            cachedAttackType = null;
        }
    }

    public void recordAttack() {
        lastAttackTime = System.currentTimeMillis();
    }
}

