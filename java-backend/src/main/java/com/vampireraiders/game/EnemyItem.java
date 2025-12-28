package com.vampireraiders.game;

public class EnemyItem {
    private final int id;
    private final int enemyTemplateId;
    private final int itemTemplateId;
    private final double dropRate; // 0.00 to 100.00

    public EnemyItem(int id, int enemyTemplateId, int itemTemplateId, double dropRate) {
        this.id = id;
        this.enemyTemplateId = enemyTemplateId;
        this.itemTemplateId = itemTemplateId;
        this.dropRate = dropRate;
    }

    public int getId() { return id; }
    public int getEnemyTemplateId() { return enemyTemplateId; }
    public int getItemTemplateId() { return itemTemplateId; }
    public double getDropRate() { return dropRate; }
}
