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
  x FLOAT DEFAULT 8000.0,
  y FLOAT DEFAULT 8000.0,
  move_speed FLOAT DEFAULT 100.0,
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
  attack_speed FLOAT DEFAULT 1.0,
  attack_range FLOAT DEFAULT 200.0,
  rarity VARCHAR(20) DEFAULT 'common', -- common, uncommon, rare, epic, legendary
  stackable BOOLEAN DEFAULT FALSE,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_type (type)
);

-- Enemy Templates (enemy definitions)
CREATE TABLE IF NOT EXISTS enemy_templates (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  level INT NOT NULL DEFAULT 1,
  hp INT NOT NULL,
  defense INT NOT NULL DEFAULT 0,
  attack INT NOT NULL DEFAULT 0,
  attack_rate FLOAT NOT NULL DEFAULT 1.0,
  move_speed FLOAT NOT NULL DEFAULT 0,
  attack_range FLOAT NOT NULL DEFAULT 1.0,
  experience INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_enemy_templates_name (name)
);

-- Enemy Item Drops (junction table for many-to-many with drop rates)
CREATE TABLE IF NOT EXISTS enemy_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  enemy_template_id INT NOT NULL,
  item_template_id INT NOT NULL,
  drop_rate DECIMAL(5,2) NOT NULL, -- Percentage 0.00 to 100.00
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (enemy_template_id) REFERENCES enemy_templates(id) ON DELETE CASCADE,
  FOREIGN KEY (item_template_id) REFERENCES item_templates(id) ON DELETE CASCADE,
  UNIQUE KEY unique_enemy_item (enemy_template_id, item_template_id),
  INDEX idx_enemy (enemy_template_id),
  INDEX idx_item (item_template_id)
);

-- World Items (items dropped in the game world)
CREATE TABLE IF NOT EXISTS world_items (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  item_template_id INT NOT NULL,
  x FLOAT NOT NULL,
  y FLOAT NOT NULL,
  quantity INT DEFAULT 1,
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
  quantity INT DEFAULT 1,
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
INSERT INTO item_templates (name, type, damage, defense, attack_speed, attack_range, rarity, description, stackable) VALUES
('Iron Dagger', 'weapon', 10, 0, 2.0, 150.0, 'common', 'A basic iron dagger', FALSE),
('Small Axe', 'weapon', 15, 0, 1.0, 200.0, 'common', 'A small axe', FALSE),
('Small Bow', 'weapon', 8, 0, 1.5, 400.0, 'common', 'A small bow', FALSE),
('Steel Sword', 'weapon', 20, 0, 1.0, 250.0, 'common', 'A well-crafted steel sword', FALSE),
('Katana', 'weapon', 15, 0, 1.5, 250.0, 'common', 'A katana from the east', FALSE),
('Leather Armor', 'armor', 0, 5, 1.0, 200.0, 'common', 'Basic iron armor', FALSE),
('Iron Armor', 'armor', 0, 15, 1.0, 200.0, 'common', 'Basic iron armor', FALSE),
('Plate Armor', 'armor', 0, 30, 1.0, 200.0, 'common', 'Sturdy plate armor', FALSE),
('Health Potion', 'consumable', 0, 0, 1.0, 200.0, 'common', 'Restores 50 health', TRUE),
('Jewel of Strength', 'jewel', 0, 0, 1.0, 200.0, 'rare', 'Increase item in 1 level', FALSE),
('Jewel of Modification', 'jewel', 0, 0, 1.0, 200.0, 'rare', 'Add or Modify mods from items', FALSE),
('Gold Coin', 'loot', 0, 0, 1.0, 200.0, 'common', 'Currency', TRUE);

-- Default enemy templates
INSERT INTO enemy_templates (name, level, hp, defense, attack, attack_rate, move_speed, attack_range, experience)
VALUES 
('Spider', 1, 30, 3, 8, 1.0, 70.0, 1.0, 5),
('Worm', 2, 90, 9, 16, 0.8, 100.0, 0.8, 15),
('Wild Dog', 3, 270, 27, 16, 1.5, 150.0, 0.3, 200),
('Goblin', 4, 300, 20, 32, 2.0, 100.0, 2.0, 300)
ON DUPLICATE KEY UPDATE name = name;

-- Sample enemy item drops with rates
INSERT INTO enemy_items (enemy_template_id, item_template_id, drop_rate) VALUES
((SELECT id FROM enemy_templates WHERE name = 'Spider'), (SELECT id FROM item_templates WHERE name = 'Gold Coin'), 60.00),
((SELECT id FROM enemy_templates WHERE name = 'Spider'), (SELECT id FROM item_templates WHERE name = 'Small Axe'), 10.00),
((SELECT id FROM enemy_templates WHERE name = 'Spider'), (SELECT id FROM item_templates WHERE name = 'Small Bow'), 10.00),
((SELECT id FROM enemy_templates WHERE name = 'Spider'), (SELECT id FROM item_templates WHERE name = 'Iron Dagger'), 10.00),
((SELECT id FROM enemy_templates WHERE name = 'Spider'), (SELECT id FROM item_templates WHERE name = 'Leather Armor'), 9.00),
((SELECT id FROM enemy_templates WHERE name = 'Spider'), (SELECT id FROM item_templates WHERE name = 'Jewel of Strength'), 1.00)
ON DUPLICATE KEY UPDATE drop_rate = VALUES(drop_rate);

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
