-- Vampire Raiders Game Database Schema

USE vampire_raiders;

-- Players Table
CREATE TABLE IF NOT EXISTS players (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  level INT DEFAULT 1,
  experience BIGINT DEFAULT 0,
  health INT DEFAULT 100,
  max_health INT DEFAULT 100,
  xp INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_username (username)
);

-- Default admin user (username: admin, password: pass)
INSERT INTO players (username, password, level, xp, health, max_health) 
VALUES ('admin', 'pass', 1, 0, 100, 100)
ON DUPLICATE KEY UPDATE username=username;

-- Item Templates (item definitions)
CREATE TABLE IF NOT EXISTS item_templates (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  type VARCHAR(50) NOT NULL, -- weapon, armor, consumable, loot
  damage INT DEFAULT 0,
  defense INT DEFAULT 0,
  rarity VARCHAR(20) DEFAULT 'common', -- common, uncommon, rare, epic, legendary
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_type (type)
);

-- Inventory (player owned items)
CREATE TABLE IF NOT EXISTS inventory (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  player_id INT NOT NULL,
  item_template_id INT NOT NULL,
  quantity INT DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE,
  FOREIGN KEY (item_template_id) REFERENCES item_templates(id),
  UNIQUE KEY unique_player_item (player_id, item_template_id),
  INDEX idx_player (player_id)
);

-- World Items (items dropped in the game world)
CREATE TABLE IF NOT EXISTS world_items (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  item_template_id INT NOT NULL,
  x FLOAT NOT NULL,
  y FLOAT NOT NULL,
  spawned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  claimed_by INT,
  claimed_at TIMESTAMP NULL,
  expires_at TIMESTAMP DEFAULT (DATE_ADD(NOW(), INTERVAL 5 MINUTE)),
  FOREIGN KEY (item_template_id) REFERENCES item_templates(id),
  FOREIGN KEY (claimed_by) REFERENCES players(id) ON DELETE SET NULL,
  INDEX idx_claimed (claimed_by),
  INDEX idx_expires (expires_at)
);

-- Sample Item Templates
INSERT INTO item_templates (name, type, damage, rarity, description) VALUES
('Iron Dagger', 'weapon', 10, 'common', 'A basic iron dagger'),
('Steel Sword', 'weapon', 15, 'common', 'A well-crafted steel sword'),
('Katana', 'weapon', 20, 'common', 'A katana from the east'),
('Iron Armor', 'armor', 0, 'common', 'Basic iron armor'),
('Plate Armor', 'armor', 0, 'common', 'Sturdy plate armor'),
('Health Potion', 'consumable', 0, 'common', 'Restores 50 health'),
('Jewel of Strength', 'jewel', 0, 'rare', 'Increase item in 1 level'),
('Gold Coin', 'loot', 0, 'common', 'Currency');
