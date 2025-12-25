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
  stackable BOOLEAN DEFAULT FALSE,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_type (type)
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

-- Inventory (player owned items - specific instances from world)
CREATE TABLE IF NOT EXISTS inventory (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  player_id INT NOT NULL,
  world_item_id BIGINT NOT NULL,
  slot_x INT DEFAULT 0,
  slot_y INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE,
  FOREIGN KEY (world_item_id) REFERENCES world_items(id) ON DELETE CASCADE,
  UNIQUE KEY unique_world_item (world_item_id),
  INDEX idx_player (player_id)
);

-- Equipped Items (what player is currently wearing)
CREATE TABLE IF NOT EXISTS equipped_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  player_id INT NOT NULL UNIQUE,
  weapon BIGINT NULL,
  helmet BIGINT NULL,
  armor BIGINT NULL,
  boots BIGINT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE,
  FOREIGN KEY (weapon) REFERENCES inventory(id) ON DELETE SET NULL,
  FOREIGN KEY (helmet) REFERENCES inventory(id) ON DELETE SET NULL,
  FOREIGN KEY (armor) REFERENCES inventory(id) ON DELETE SET NULL,
  FOREIGN KEY (boots) REFERENCES inventory(id) ON DELETE SET NULL
);


-- Mod Templates (predefined mod definitions)
CREATE TABLE IF NOT EXISTS mod_templates (
  id INT AUTO_INCREMENT PRIMARY KEY,
  mod_type ENUM('LEVEL', 'LIFE', 'DEFENSE', 'DAMAGE', 'SKILL') NOT NULL,
  mod_value INT NOT NULL,
  mod_name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_type (mod_type)
);

-- Item Mods (links world items to their mods)
CREATE TABLE IF NOT EXISTS item_mods (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  world_item_id BIGINT NOT NULL,
  mod_template_id INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (world_item_id) REFERENCES world_items(id) ON DELETE CASCADE,
  FOREIGN KEY (mod_template_id) REFERENCES mod_templates(id) ON DELETE CASCADE,
  INDEX idx_world_item (world_item_id),
  INDEX idx_mod_template (mod_template_id)
);

-- Sample Item Templates
INSERT INTO item_templates (name, type, damage, rarity, description, stackable) VALUES
('Iron Dagger', 'weapon', 10, 'common', 'A basic iron dagger', FALSE),
('Steel Sword', 'weapon', 15, 'common', 'A well-crafted steel sword', FALSE),
('Katana', 'weapon', 20, 'common', 'A katana from the east', FALSE),
('Iron Armor', 'armor', 0, 'common', 'Basic iron armor', FALSE),
('Plate Armor', 'armor', 0, 'common', 'Sturdy plate armor', FALSE),
('Health Potion', 'consumable', 0, 'common', 'Restores 50 health', TRUE),
('Jewel of Strength', 'jewel', 0, 'rare', 'Increase item in 1 level', FALSE),
('Jewel of Modification', 'jewel', 0, 'rare', 'Add or Modify mods from items', FALSE),
('Gold Coin', 'loot', 0, 'common', 'Currency', FALSE);

-- Sample Mod Templates
INSERT INTO mod_templates (mod_type, mod_value, mod_name) VALUES
('LEVEL', 1, 'Enhanced I'),
('LEVEL', 2, 'Enhanced II'),
('LEVEL', 3, 'Enhanced III'),
('LIFE', 50, 'Vitality'),
('DEFENSE', 5, 'Fortified'),
('DAMAGE', 10, 'Increase'),
('SKILL', 10, 'Lifesteal'),
('SKILL', 2, 'Multiplier');
