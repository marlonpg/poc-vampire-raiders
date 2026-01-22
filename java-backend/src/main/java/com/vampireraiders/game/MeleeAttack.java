package com.vampireraiders.game;

import java.util.HashSet;
import java.util.Set;

/**
 * Represents a melee attack from a player.
 * The attack is a semicircle in front of the player that damages all enemies within it.
 * The attack animates from left to right (like a sword swing).
 * Each enemy is only damaged once per melee attack.
 */
public class MeleeAttack {
    private static long idCounter = 1;
    
    private final long id;
    private final int playerId;  // peer_id of player who attacked
    private final float x;  // Player x position at attack time
    private final float y;  // Player y position at attack time
    private final float radius;  // Semicircle radius
    private final long startTimeMs;  // When the attack was initiated
    private final long durationMs;  // How long the attack lasts
    
    // Semicircle direction: 0-360 degrees where player is the center
    // Direction indicates which way the semicircle is facing (the swing direction)
    private final float directionDegrees;  // 0-360: 0=right, 90=down, 180=left, 270=up
    
    // Track which enemies have been hit to prevent multiple hits per attack
    private final Set<Integer> hitEnemies = new HashSet<>();

    public MeleeAttack(int playerId, float x, float y, float radius, long durationMs, float directionDegrees) {
        this.id = idCounter++;
        this.playerId = playerId;
        this.x = x;
        this.y = y;
        this.radius = radius;
        this.durationMs = durationMs;
        this.startTimeMs = System.currentTimeMillis();
        this.directionDegrees = directionDegrees % 360f;
    }

    public boolean isActive(long currentTimeMs) {
        return (currentTimeMs - startTimeMs) < durationMs;
    }
    
    public boolean hasHitEnemy(int enemyId) {
        return hitEnemies.contains(enemyId);
    }
    
    public void markEnemyHit(int enemyId) {
        hitEnemies.add(enemyId);
    }

    // Getters
    public long getId() { return id; }
    public int getPlayerId() { return playerId; }
    public float getX() { return x; }
    public float getY() { return y; }
    public float getRadius() { return radius; }
    public long getStartTimeMs() { return startTimeMs; }
    public long getDurationMs() { return durationMs; }
    public float getDirectionDegrees() { return directionDegrees; }
}
