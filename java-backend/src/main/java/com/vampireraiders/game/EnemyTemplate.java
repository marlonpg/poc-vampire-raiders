package com.vampireraiders.game;

public class EnemyTemplate {
    private final int id;
    private final String name;
    private final int level;
    private final int hp;
    private final int defense;
    private final int attack;
    private final float attackRate;
    private final float moveSpeed;
    private final float attackRange;
    private final int experience;

    public EnemyTemplate(int id, String name, int level, int hp, int defense, int attack, 
                        float attackRate, float moveSpeed, float attackRange, int experience) {
        this.id = id;
        this.name = name;
        this.level = level;
        this.hp = hp;
        this.defense = defense;
        this.attack = attack;
        this.attackRate = attackRate;
        this.moveSpeed = moveSpeed;
        this.attackRange = attackRange;
        this.experience = experience;
    }

    public int getId() { return id; }
    public String getName() { return name; }
    public int getLevel() { return level; }
    public int getHp() { return hp; }
    public int getDefense() { return defense; }
    public int getAttack() { return attack; }
    public float getAttackRate() { return attackRate; }
    public float getMoveSpeed() { return moveSpeed; }
    public float getAttackRange() { return attackRange; }
    public int getExperience() { return experience; }
}
