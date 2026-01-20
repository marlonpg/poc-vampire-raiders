package com.vampireraiders.game;

/**
 * Telegraph attack types with dimensions for each enemy
 */
public enum TelegraphType {
    CIRCLE("CIRCLE", 96.0f, 0.0f),          // Spider: circle with 96px diameter
    RECTANGLE_36_48("RECTANGLE", 36.0f, 48.0f),    // Worm: 36px wide, 48px deep
    RECTANGLE_48_72("RECTANGLE", 48.0f, 72.0f),    // Wild Dog: 48px wide, 72px deep
    RECTANGLE_72_72("RECTANGLE", 72.0f, 72.0f),    // Hound: 72x72
    RECTANGLE_48_96("RECTANGLE", 48.0f, 96.0f),    // Elite Wild Dog: 48px wide, 96px deep
    RECTANGLE_96_96("RECTANGLE", 96.0f, 96.0f),    // Giant: 96x96
    RECTANGLE_20_120("RECTANGLE", 20.0f, 120.0f);  // Skeleton: 20px wide, 120px deep

    private final String type;
    private final float width;  // For CIRCLE: diameter; For RECTANGLE: width
    private final float depth;  // For CIRCLE: 0; For RECTANGLE: depth

    TelegraphType(String type, float width, float depth) {
        this.type = type;
        this.width = width;
        this.depth = depth;
    }

    public String getType() {
        return type;
    }

    public float getWidth() {
        return width;
    }

    public float getDepth() {
        return depth;
    }

    /**
     * Check if this telegraph type is a circle
     */
    public boolean isCircle() {
        return "CIRCLE".equals(type);
    }

    /**
     * Check if this telegraph type is a rectangle
     */
    public boolean isRectangle() {
        return "RECTANGLE".equals(type);
    }
}
