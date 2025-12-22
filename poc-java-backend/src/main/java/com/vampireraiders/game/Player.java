package com.vampireraiders.game;

public class Player {
    private final int peerId;
    private final String username;
    private float x;
    private float y;
    private int health;
    private int maxHealth;
    private int xp;
    private int level;
    private float velocityX;
    private float velocityY;
    private final float speed = 200f;
    private long lastUpdateTime;
    private long lastAttackTime = 0;
    private final long attackCooldownMs = 500;  // Attack every 0.5 seconds

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
        x += velocityX * speed * deltaTime;
        y += velocityY * speed * deltaTime;
        lastUpdateTime = System.currentTimeMillis();
    }

    public void setInputDirection(float velX, float velY) {
        this.velocityX = velX;
        this.velocityY = velY;
    }

    public void takeDamage(int damage) {
        this.health = Math.max(0, health - damage);
    }

    public void heal(int amount) {
        this.health = Math.min(maxHealth, health + amount);
    }

    public void gainXP(int amount) {
        this.xp += amount;
        checkLevelUp();
    }

    private void checkLevelUp() {
        int xpRequired = level * 100;
        if (xp >= xpRequired) {
            level++;
            maxHealth += 20;
            health = maxHealth;
            xp = 0;
        }
    }

    // Getters
    public int getPeerId() { return peerId; }
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

    public boolean isAlive() {
        return health > 0;
    }

    public boolean canAttack() {
        return System.currentTimeMillis() - lastAttackTime >= attackCooldownMs;
    }

    public void recordAttack() {
        lastAttackTime = System.currentTimeMillis();
    }
}

