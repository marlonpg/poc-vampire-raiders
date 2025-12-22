package com.vampireraiders.game;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

public class GameState {
    private final Map<Integer, Player> players = new ConcurrentHashMap<>();
    private final List<Enemy> enemies = Collections.synchronizedList(new ArrayList<>());
    private final List<Bullet> bullets = Collections.synchronizedList(new ArrayList<>());
    private long worldTime = 0;
    private boolean running = false;

    public synchronized void addPlayer(int peerId, Player player) {
        players.put(peerId, player);
    }

    public synchronized Player getPlayer(int peerId) {
        return players.get(peerId);
    }

    public synchronized void removePlayer(int peerId) {
        players.remove(peerId);
    }

    public Map<Integer, Player> getAllPlayers() {
        return new HashMap<>(players);
    }

    public int getPlayerCount() {
        return players.size();
    }

    public void addEnemy(Enemy enemy) {
        enemies.add(enemy);
    }

    public void removeEnemy(Enemy enemy) {
        enemies.remove(enemy);
    }

    public List<Enemy> getAllEnemies() {
        return new ArrayList<>(enemies);
    }

    public int getEnemyCount() {
        return enemies.size();
    }

    public void incrementWorldTime() {
        worldTime++;
    }

    public long getWorldTime() {
        return worldTime;
    }

    public void setRunning(boolean running) {
        this.running = running;
    }

    public boolean isRunning() {
        return running;
    }

    public void reset() {
        players.clear();
        enemies.clear();
        bullets.clear();
        worldTime = 0;
    }

    public void addBullet(Bullet bullet) {
        bullets.add(bullet);
    }

    public List<Bullet> getAllBullets() {
        return new ArrayList<>(bullets);
    }

    public void removeBullet(Bullet bullet) {
        bullets.remove(bullet);
    }
}
