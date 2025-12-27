package com.vampireraiders.game;

public class Enemy {
    private static int idCounter = 1;
    
    private final int id;
    private float x;
    private float y;
    private int health;
    private final int maxHealth;
    private final int damage;
    private final int defense;
    private final float speed;
    private final float attackRate;
    private final float attackRange;
    private final int experienceReward;
    private final int level;
    private final String templateName;
    private long spawnTime;

    public Enemy(float x, float y, EnemyTemplate template) {
        this.id = idCounter++;
        this.x = x;
        this.y = y;
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
        return experienceReward;
    }

    // Getters
    public int getId() { return id; }
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
}
