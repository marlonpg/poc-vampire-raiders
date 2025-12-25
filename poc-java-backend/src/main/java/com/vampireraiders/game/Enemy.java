package com.vampireraiders.game;

import java.util.Random;

public class Enemy {
    private static final Random random = new Random();
    private static int idCounter = 1;
    
    private final int id;
    private float x;
    private float y;
    private int health;
    private final int maxHealth;
    private int damage;
    private final float speed;
    private EnemyType type;
    private long spawnTime;

    public enum EnemyType {
        BASIC(50, 10, 100f),
        FAST(30, 5, 200f),
        STRONG(100, 20, 80f);

        public final int hp;
        public final int dmg;
        public final float spd;

        EnemyType(int hp, int dmg, float spd) {
            this.hp = hp;
            this.dmg = dmg;
            this.spd = spd;
        }
    }

    public Enemy(float x, float y, EnemyType type) {
        this.id = idCounter++;
        this.x = x;
        this.y = y;
        this.type = type;
        this.maxHealth = type.hp;
        this.health = type.hp;
        this.damage = type.dmg;
        this.speed = type.spd;
        this.spawnTime = System.currentTimeMillis();
    }

    public void update(float deltaTime, Player targetPlayer) {
        if (targetPlayer == null || !targetPlayer.isAlive()) return;

        // Calculate distance to player
        float dx = targetPlayer.getX() - x;
        float dy = targetPlayer.getY() - y;
        float distance = (float) Math.sqrt(dx * dx + dy * dy);

        // Only chase player if within 7 tiles (224 pixels)
        float chaseDistance = 7 * 32;
        if (distance > 0 && distance <= chaseDistance) {
            x += (dx / distance) * speed * deltaTime;
            y += (dy / distance) * speed * deltaTime;
        }
    }

    public void takeDamage(int damage) {
        this.health = Math.max(0, health - damage);
    }

    public boolean isAlive() {
        return health > 0;
    }

    public int getRewardXP() {
        return type.hp + type.dmg * 2;
    }

    // Getters
    public int getId() { return id; }
    public float getX() { return x; }
    public float getY() { return y; }
    public int getHealth() { return health; }
    public int getMaxHealth() { return maxHealth; }
    public int getDamage() { return damage; }
    public float getSpeed() { return speed; }
    public EnemyType getType() { return type; }
    public long getSpawnTime() { return spawnTime; }

    public static Enemy createRandomEnemy(float x, float y) {
        EnemyType[] types = EnemyType.values();
        return new Enemy(x, y, types[random.nextInt(types.length)]);
    }
}
