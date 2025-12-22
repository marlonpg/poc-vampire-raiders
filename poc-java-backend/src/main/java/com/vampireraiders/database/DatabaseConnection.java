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
            config.setJdbcUrl("jdbc:mysql://localhost:3306/vampire_raiders");
            config.setUsername("game_user");
            config.setPassword("gamepassword");
            config.setMaximumPoolSize(10);
            config.setMinimumIdle(2);
            config.setConnectionTimeout(30000);
            config.setIdleTimeout(600000);
            config.setMaxLifetime(1800000);

            dataSource = new HikariDataSource(config);
            Logger.info("Database connection pool initialized");
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
}
