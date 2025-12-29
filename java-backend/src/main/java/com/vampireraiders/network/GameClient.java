package com.vampireraiders.network;

import com.vampireraiders.game.Player;
import java.io.PrintWriter;

public class GameClient {
    private final int peerId;
    private final String ipAddress;
    private final int port;
    private Player player;
    private boolean authenticated = false;
    private long lastHeartbeat;
    private final long connectionTime;
    private PrintWriter outputStream;

    public GameClient(int peerId, String ipAddress, int port) {
        this.peerId = peerId;
        this.ipAddress = ipAddress;
        this.port = port;
        this.lastHeartbeat = System.currentTimeMillis();
        this.connectionTime = System.currentTimeMillis();
        this.outputStream = null;
    }

    public void updateHeartbeat() {
        this.lastHeartbeat = System.currentTimeMillis();
    }

    public boolean isConnected(long timeoutMs) {
        return (System.currentTimeMillis() - lastHeartbeat) < timeoutMs;
    }

    // Getters and Setters
    public int getPeerId() { return peerId; }
    public String getIpAddress() { return ipAddress; }
    public int getPort() { return port; }
    public Player getPlayer() { return player; }
    public void setPlayer(Player player) { this.player = player; }
    public boolean isAuthenticated() { return authenticated; }
    public void setAuthenticated(boolean authenticated) { this.authenticated = authenticated; }
    public long getLastHeartbeat() { return lastHeartbeat; }
    public long getConnectionTime() { return connectionTime; }
    public long getConnectionDuration() { return System.currentTimeMillis() - connectionTime; }
    public PrintWriter getOutputStream() { return outputStream; }
    public void setOutputStream(PrintWriter writer) { this.outputStream = writer; }
}
