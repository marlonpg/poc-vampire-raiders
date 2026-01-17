package com.vampireraiders.game;

public class Enemy {
    private static int idCounter = 1;
    
    private final int id;
    private final int templateId;
    private float x;
    private float y;
    private int health;
    private final int maxHealth;
    private final int damage;
    private final int defense;
    private final float speed;
    private final float attackRate;  // attacks per second
    private final float attackRange;
    private final int experienceReward;
    private final int level;
    private final String templateName;
    private long spawnTime;
    private long lastAttackTime = 0;  // Track when enemy last attacked
    private long deathTime = -1;  // Track when enemy died (for respawn)
    private static final long RESPAWN_DELAY_MS = 10000;  // 30 seconds
    
    // Telegraph attack system
    public enum AttackState { IDLE, TELEGRAPHING, ATTACKING }
    private AttackState attackState = AttackState.IDLE;
    private long telegraphStartTime = 0;
    private static final long TELEGRAPH_DURATION_MS = 2000;  // 1 second telegraph
    private float telegraphTargetX = 0;  // Position where attack will happen
    private float telegraphTargetY = 0;
    private int spawnLevel;  // Track which level zone this enemy spawns in
    private float originalSpawnX;  // Original spawn position for respawn
    private float originalSpawnY;

    public Enemy(float x, float y, EnemyTemplate template) {
        this.id = idCounter++;
        this.templateId = template.getId();
        this.x = x;
        this.y = y;
        this.originalSpawnX = x;  // Store original position
        this.originalSpawnY = y;
        this.spawnLevel = 1;  // Default to PV1, will be set by spawner
        this.templateName = template.getName();
        this.level = template.getLevel();
        this.maxHealth = template.getHp();
        this.health = template.getHp();
        this.damage = template.getAttack();
        this.defense = template.getDefense();
        this.speed = template.getMoveSpeed();
        this.attackRate = template.getAttackRate();
        this.attackRange = template.getAttackRange();
        this.experienceReward = template.getExperience();
        this.spawnTime = System.currentTimeMillis();
    }

    public void update(float deltaTime, Player targetPlayer) {
        if (targetPlayer == null || !targetPlayer.isAlive()) return;
        
        // Don't move while telegraphing an attack
        if (attackState == AttackState.TELEGRAPHING) {
            return;
        }

        // Calculate distance to player
        float dx = targetPlayer.getX() - x;
        float dy = targetPlayer.getY() - y;
        float distance = (float) Math.sqrt(dx * dx + dy * dy);

        // Only chase player if within 7 tiles (224 pixels)
        float chaseDistance = 7 * 32;
        if (distance > 0 && distance <= chaseDistance) {
            float newX = x + (dx / distance) * speed * deltaTime;
            float newY = y + (dy / distance) * speed * deltaTime;
            
            // Check if walkable for enemies (enemies can't enter safe zone)
            if (GameWorld.isEnemyWalkable(newX, newY)) {
                x = newX;
                y = newY;
            }
        }
    }

    public void takeDamage(int damage) {
        this.health = Math.max(0, health - damage);
    }

    public boolean canAttack() {
        // attackRate is attacks per second, so cooldown = 1000 / attackRate milliseconds
        long attackCooldownMs = (long) (1000.0 / attackRate);
        return System.currentTimeMillis() - lastAttackTime >= attackCooldownMs;
    }

    public void recordAttack() {
        lastAttackTime = System.currentTimeMillis();
    }

    public boolean isAlive() {
        return health > 0;
    }

    public void die() {
        if (health <= 0) {
            deathTime = System.currentTimeMillis();
        }
    }

    public boolean isReadyToRespawn() {
        if (health > 0) return false;  // Not dead
        if (deathTime < 0) return false;  // Never died
        long timeSinceDeath = System.currentTimeMillis() - deathTime;
        return timeSinceDeath >= RESPAWN_DELAY_MS;
    }

    public void respawn() {
        this.health = maxHealth;
        this.deathTime = -1;
        this.lastAttackTime = 0;
        this.spawnTime = System.currentTimeMillis();
        this.attackState = AttackState.IDLE;
        this.telegraphStartTime = 0;
        // Position will be updated by SpawnerSystem using setSpawnLevel
    }

    public void respawnAt(float newX, float newY) {
        this.x = newX;
        this.y = newY;
        respawn();
    }
    public float getOriginalSpawnX() {
        return originalSpawnX;
    }

    public float getOriginalSpawnY() {
        return originalSpawnY;
    }
    public long getDeathTime() {
        return deathTime;
    }

    public int getSpawnLevel() {
        return spawnLevel;
    }

    public void setSpawnLevel(int level) {
        this.spawnLevel = level;
    }

    public int getRewardXP() {
        return experienceReward;
    }

    // Getters
    public int getId() { return id; }
    public int getTemplateId() { return templateId; }
    public float getX() { return x; }
    public float getY() { return y; }
    public int getHealth() { return health; }
    public int getMaxHealth() { return maxHealth; }
    public int getDamage() { return damage; }
    public int getDefense() { return defense; }
    public float getSpeed() { return speed; }
    public float getAttackRate() { return attackRate; }
    public float getAttackRange() { return attackRange; }
    public int getExperienceReward() { return experienceReward; }
    public int getLevel() { return level; }
    public String getTemplateName() { return templateName; }
    public long getSpawnTime() { return spawnTime; }
    
    // Telegraph attack getters and setters
    public AttackState getAttackState() { return attackState; }
    public float getTelegraphTargetX() { return telegraphTargetX; }
    public float getTelegraphTargetY() { return telegraphTargetY; }
    public long getTelegraphStartTime() { return telegraphStartTime; }
    
    public void startTelegraph(float targetX, float targetY) {
        if (attackState == AttackState.IDLE && canAttack()) {
            attackState = AttackState.TELEGRAPHING;
            telegraphStartTime = System.currentTimeMillis();
            telegraphTargetX = targetX;
            telegraphTargetY = targetY;
        }
    }
    
    public boolean isTelegraphExpired() {
        return attackState == AttackState.TELEGRAPHING && 
               (System.currentTimeMillis() - telegraphStartTime >= TELEGRAPH_DURATION_MS);
    }
    
    public void resolveTelegraph() {
        attackState = AttackState.ATTACKING;
    }
    
    public void endAttack() {
        attackState = AttackState.IDLE;
        recordAttack();
    }
}
