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
    private int cachedTotalDamage = 0;

    // Cached equipped armor stats (to avoid DB queries every defense calculation)
    private int cachedArmorDefense = 0;
    private int cachedArmorLevelMod = 0;
    private int cachedGlovesDefense = 0;
    private int cachedGlovesLevelMod = 0;
    private int cachedBootsDefense = 0;
    private int cachedBootsLevelMod = 0;
    private int cachedTotalDefense = 0;

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
    public int getPeerId() {
        return peerId;
    }

    public int getDatabaseId() {
        return databaseId;
    }

    public String getUsername() {
        return username;
    }

    public float getX() {
        return x;
    }

    public float getY() {
        return y;
    }

    public int getHealth() {
        return health;
    }

    public int getMaxHealth() {
        return maxHealth;
    }

    public int getXP() {
        return xp;
    }

    public int getLevel() {
        return level;
    }

    public float getVelocityX() {
        return velocityX;
    }

    public float getVelocityY() {
        return velocityY;
    }

    public long getLastUpdateTime() {
        return lastUpdateTime;
    }

    // Setters (for loading from database)
    public void setHealth(int h) {
        this.health = Math.max(0, h);
    }

    public void setMaxHealth(int mh) {
        this.maxHealth = mh;
    }

    public void setLevel(int l) {
        this.level = l;
    }

    public void setXP(int x) {
        this.xp = x;
    }

    public void setMoveSpeed(float moveSpeed) {
        this.moveSpeed = moveSpeed;
    }

    public void setPosition(float x, float y) {
        this.x = x;
        this.y = y;
    }

    public void setDatabaseId(int id) {
        this.databaseId = id;
        // Load equipped items cache when database ID is set
        refreshEquippedItemsCache();
    }

    public float getMoveSpeed() {
        return moveSpeed;
    }

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

    public int getCachedTotalDamage() {
        return cachedTotalDamage;
    }

    public int getCachedArmorDefense() {
        return cachedArmorDefense;
    }

    public int getCachedArmorLevelMod() {
        return cachedArmorLevelMod;
    }

    public int getCachedGlovesDefense() {
        return cachedGlovesDefense;
    }

    public int getCachedGlovesLevelMod() {
        return cachedGlovesLevelMod;
    }

    public int getCachedBootsDefense() {
        return cachedBootsDefense;
    }

    public int getCachedBootsLevelMod() {
        return cachedBootsLevelMod;
    }

    public int getCachedTotalDefense() {
        return cachedTotalDefense;
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

        // Load weapon stats
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
            cachedAttackRange = 50.0f;
            cachedWeaponDamage = 0;
            cachedWeaponLevelMod = 0;
            cachedAttackType = null;
        }

        // Load armor stats
        Map<String, Object> armor = EquippedItemRepository.getEquippedArmor(databaseId);
        if (armor != null) {
            // Extract armor stats
            if (armor.containsKey("defense")) {
                cachedArmorDefense = ((Number) armor.get("defense")).intValue();
            } else {
                cachedArmorDefense = 0;
            }

            // Cache armor LEVEL mods
            if (armor.containsKey("world_item_id") && armor.get("world_item_id") instanceof Number) {
                long worldItemId = ((Number) armor.get("world_item_id")).longValue();
                cachedArmorLevelMod = ItemModRepository.getModValueForWorldItem(worldItemId, "LEVEL");
            } else {
                cachedArmorLevelMod = 0;
            }
        } else {
            // No armor equipped, use defaults
            cachedArmorDefense = 0;
            cachedArmorLevelMod = 0;
        }

        // Load gloves stats
        Map<String, Object> gloves = EquippedItemRepository.getEquippedGloves(databaseId);
        if (gloves != null) {
            // Extract gloves stats
            if (gloves.containsKey("defense")) {
                cachedGlovesDefense = ((Number) gloves.get("defense")).intValue();
            } else {
                cachedGlovesDefense = 0;
            }

            // Cache gloves LEVEL mods
            if (gloves.containsKey("world_item_id") && gloves.get("world_item_id") instanceof Number) {
                long worldItemId = ((Number) gloves.get("world_item_id")).longValue();
                cachedGlovesLevelMod = ItemModRepository.getModValueForWorldItem(worldItemId, "LEVEL");
            } else {
                cachedGlovesLevelMod = 0;
            }
        } else {
            // No gloves equipped, use defaults
            cachedGlovesDefense = 0;
            cachedGlovesLevelMod = 0;
        }

        // Load boots stats
        Map<String, Object> boots = EquippedItemRepository.getEquippedBoots(databaseId);
        if (boots != null) {
            // Extract boots stats
            if (boots.containsKey("defense")) {
                cachedBootsDefense = ((Number) boots.get("defense")).intValue();
            } else {
                cachedBootsDefense = 0;
            }

            // Cache boots LEVEL mods
            if (boots.containsKey("world_item_id") && boots.get("world_item_id") instanceof Number) {
                long worldItemId = ((Number) boots.get("world_item_id")).longValue();
                cachedBootsLevelMod = ItemModRepository.getModValueForWorldItem(worldItemId, "LEVEL");
            } else {
                cachedBootsLevelMod = 0;
            }
        } else {
            // No boots equipped, use defaults
            cachedBootsDefense = 0;
            cachedBootsLevelMod = 0;
        }

        // Calculate and cache total defense from all armor items
        recalculateTotalDefense();

        // Calculate and cache total damage (based on level + weapon + LEVEL mod scaling)
        recalculateTotalDamage();
    }

    /**
     * Recalculates total defense from all equipped armor items (armor + gloves + boots)
     * and applies LEVEL mod scaling to each item individually.
     */
    private void recalculateTotalDefense() {
        int totalDefense = 0;

        // Armor defense (with LEVEL mod scaling)
        int armorDefense = cachedArmorDefense;
        if (cachedArmorLevelMod > 0) {
            float multiplier = 1.0f + (cachedArmorLevelMod * 0.10f);
            armorDefense = Math.max(0, Math.round(armorDefense * multiplier));
        }
        totalDefense += armorDefense;

        // Gloves defense (with LEVEL mod scaling)
        int glovesDefense = cachedGlovesDefense;
        if (cachedGlovesLevelMod > 0) {
            float multiplier = 1.0f + (cachedGlovesLevelMod * 0.10f);
            glovesDefense = Math.max(0, Math.round(glovesDefense * multiplier));
        }
        totalDefense += glovesDefense;

        // Boots defense (with LEVEL mod scaling)
        int bootsDefense = cachedBootsDefense;
        if (cachedBootsLevelMod > 0) {
            float multiplier = 1.0f + (cachedBootsLevelMod * 0.10f);
            bootsDefense = Math.max(0, Math.round(bootsDefense * multiplier));
        }
        totalDefense += bootsDefense;

        cachedTotalDefense = totalDefense;
    }

    /**
     * Recalculates total damage from level + equipped weapon + LEVEL mod scaling.
     */
    private void recalculateTotalDamage() {
        // Base damage: 1 + level + weapon damage
        int baseDamage = 1 + level + cachedWeaponDamage;

        // Mod scaling: LEVEL increases damage by 10% per mod_value
        if (cachedWeaponLevelMod > 0) {
            float multiplier = 1.0f + (cachedWeaponLevelMod * 0.10f);
            baseDamage = Math.max(1, Math.round(baseDamage * multiplier));
        }

        cachedTotalDamage = baseDamage;
    }

    public void recordAttack() {
        lastAttackTime = System.currentTimeMillis();
    }
}

