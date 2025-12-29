package com.vampireraiders.network;

import java.util.EventListener;

public interface NetworkEventListener extends EventListener {
    void onClientConnected(int peerId, String ipAddress);
    void onClientDisconnected(int peerId);
    void onClientInput(int peerId, String inputType, float dirX, float dirY);
    void onServerError(String errorMessage);
}
