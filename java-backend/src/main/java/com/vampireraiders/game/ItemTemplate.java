package com.vampireraiders.game;

public class ItemTemplate {
    private final int id;
    private final String name;
    private final String type;
    private final int damage;
    private final int defense;
    private final float attackSpeed;
    private final float attackRange;
    private final String rarity;
    private final boolean stackable;
    private final String description;

    public ItemTemplate(int id, String name, String type, int damage, int defense, float attackSpeed, float attackRange, String rarity, boolean stackable, String description) {
        this.id = id;
        this.name = name;
        this.type = type;
        this.damage = damage;
        this.defense = defense;
        this.attackSpeed = attackSpeed;
        this.attackRange = attackRange;
        this.rarity = rarity;
        this.stackable = stackable;
        this.description = description;
    }

    public int getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getType() {
        return type;
    }

    public int getDamage() {
        return damage;
    }

    public int getDefense() {
        return defense;
    }

    public float getAttackSpeed() {
        return attackSpeed;
    }

    public float getAttackRange() {
        return attackRange;
    }

    public String getRarity() {
        return rarity;
    }

    public boolean isStackable() {
        return stackable;
    }

    public String getDescription() {
        return description;
    }
}
