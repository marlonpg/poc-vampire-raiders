package com.vampireraiders.database;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import com.vampireraiders.util.Logger;

import java.sql.Connection;
import java.sql.SQLException;

public class DatabaseConnection {
    private static HikariDataSource dataSource;

    static {
        try {
            HikariConfig config = new HikariConfig();

            // Read configuration from environment (with sane defaults for Docker Compose)
            String host = env("DATABASE_HOST", "localhost");
            String port = env("DATABASE_PORT", "3306");
            String dbName = env("DATABASE_NAME", "vampire_raiders");
            String username = env("DATABASE_USER", "game_user");
            String password = env("DATABASE_PASSWORD", "gamepassword");

            String jdbcUrl = String.format(
                "jdbc:mysql://%s:%s/%s?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC",
                host, port, dbName
            );

            config.setJdbcUrl(jdbcUrl);
            config.setUsername(username);
            config.setPassword(password);
            config.setMaximumPoolSize(10);
            config.setMinimumIdle(2);
            config.setConnectionTimeout(30000);
            config.setIdleTimeout(600000);
            config.setMaxLifetime(1800000);

            dataSource = new HikariDataSource(config);
            Logger.info("Database connection pool initialized: " + jdbcUrl + " (user=" + username + ")");
        } catch (Exception e) {
            Logger.error("Failed to initialize database connection pool: " + e.getMessage());
            e.printStackTrace();
        }
    }

    public static Connection getConnection() throws SQLException {
        return dataSource.getConnection();
    }

    public static void close() {
        if (dataSource != null) {
            dataSource.close();
        }
    }

    private static String env(String key, String def) {
        String v = System.getenv(key);
        return (v != null && !v.isEmpty()) ? v : def;
    }
}
