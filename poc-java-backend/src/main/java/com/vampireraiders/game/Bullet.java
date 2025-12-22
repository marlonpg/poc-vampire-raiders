package com.vampireraiders.game;

public class Bullet {
    private static int idCounter = 1;
    
    private final int id;
    private final int shooterId;  // peer_id of player who shot
    private float x;
    private float y;
    private float vx;  // velocity x
    private float vy;  // velocity y
    private final float speed = 400f;
    private final float lifetime = 3f;  // seconds
    private float age = 0f;
    private final float radius = 5f;

    public Bullet(int shooterId, float x, float y, float targetX, float targetY) {
        this.id = idCounter++;
        this.shooterId = shooterId;
        this.x = x;
        this.y = y;

        // Calculate direction towards target
        float dx = targetX - x;
        float dy = targetY - y;
        float distance = (float) Math.sqrt(dx * dx + dy * dy);

        if (distance > 0) {
            vx = (dx / distance) * speed;
            vy = (dy / distance) * speed;
        } else {
            vx = 0;
            vy = 0;
        }
    }

    public void update(float deltaTime) {
        x += vx * deltaTime;
        y += vy * deltaTime;
        age += deltaTime;
    }

    public boolean isAlive() {
        return age < lifetime;
    }

    public boolean collidedWith(Enemy enemy) {
        float dx = enemy.getX() - x;
        float dy = enemy.getY() - y;
        float distance = (float) Math.sqrt(dx * dx + dy * dy);
        return distance < (radius + 20f);  // enemy collision radius ~20
    }

    // Getters
    public int getId() { return id; }
    public int getShooterId() { return shooterId; }
    public float getX() { return x; }
    public float getY() { return y; }
    public float getVx() { return vx; }
    public float getVy() { return vy; }
    public float getRadius() { return radius; }
    public float getAge() { return age; }
}
