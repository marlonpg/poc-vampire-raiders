package com.vampireraiders.game;

public class WorldItem {
    private final long id;
    private final int itemTemplateId;
    private final float x;
    private final float y;
    private Integer claimedBy; // null when unclaimed
    private String templateName; // optional helper for broadcasting

    public WorldItem(long id, int itemTemplateId, float x, float y, Integer claimedBy) {
        this.id = id;
        this.itemTemplateId = itemTemplateId;
        this.x = x;
        this.y = y;
        this.claimedBy = claimedBy;
    }

    public long getId() {
        return id;
    }

    public int getItemTemplateId() {
        return itemTemplateId;
    }

    public float getX() {
        return x;
    }

    public float getY() {
        return y;
    }

    public Integer getClaimedBy() {
        return claimedBy;
    }

    public void setClaimedBy(Integer claimedBy) {
        this.claimedBy = claimedBy;
    }

    public String getTemplateName() {
        return templateName;
    }

    public void setTemplateName(String templateName) {
        this.templateName = templateName;
    }
}
