package com.vampireraiders.config;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

public class ServerConfig {
    private static ServerConfig instance;
    private Properties properties;

    private ServerConfig() {
        properties = new Properties();
        try (InputStream input = ServerConfig.class.getClassLoader()
                .getResourceAsStream("application.properties")) {
            if (input != null) {
                properties.load(input);
            }
        } catch (IOException e) {
            System.err.println("Failed to load properties: " + e.getMessage());
        }
    }

    public static ServerConfig getInstance() {
        if (instance == null) {
            instance = new ServerConfig();
        }
        return instance;
    }

    public int getPort() {
        return Integer.parseInt(properties.getProperty("server.port", "7777"));
    }

    public String getHost() {
        return properties.getProperty("server.host", "0.0.0.0");
    }

    public int getTickRate() {
        return Integer.parseInt(properties.getProperty("game.tick-rate", "60"));
    }

    public int getMaxPlayers() {
        return Integer.parseInt(properties.getProperty("game.max-players", "4"));
    }

    public int getSpawnerInterval() {
        return Integer.parseInt(properties.getProperty("spawner.spawn-interval", "5000"));
    }

    public int getMaxEnemies() {
        return Integer.parseInt(properties.getProperty("spawner.max-enemies", "10"));
    }

    public String getLogLevel() {
        return properties.getProperty("logging.level.com.vampireraiders", "DEBUG");
    }
}
