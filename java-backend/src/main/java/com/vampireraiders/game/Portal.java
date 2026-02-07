package com.vampireraiders.game;

public class Portal {
    private final float x;
    private final float y;
    private final String targetMapId;

    public Portal(float x, float y, String targetMapId) {
        this.x = x;
        this.y = y;
        this.targetMapId = targetMapId;
    }

    public float getX() {
        return x;
    }

    public float getY() {
        return y;
    }

    public String getTargetMapId() {
        return targetMapId;
    }
}
