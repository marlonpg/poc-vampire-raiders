# Vampire Raiders - Project Structure

## Folder Organization

### `/scenes/`
Contains all scene files (.tscn)

- **player/** - Player character scenes
- **enemies/** - Enemy types (basic, elite, mini-boss)
- **weapons/** - Weapon scenes (Blood Daggers, Bat Swarm, Blood Nova, etc.)
- **loot/** - Loot item scenes (Blood Vials, Relics, Cursed items)
- **ui/** - UI scenes (HUD, inventory, menus)
- **world/** - Map and environment scenes

### `/scripts/`
Contains all GDScript files (.gd)

- **player/** - Player movement, input, stats
- **enemies/** - Enemy AI, spawning, behavior
- **weapons/** - Weapon logic, projectiles, evolutions
- **systems/** - Core game systems (leveling, inventory, extraction)
- **managers/** - Singleton managers (GameManager, SpawnManager, etc.)

### `/assets/`
Contains all art and audio files

- **sprites/** - Character sprites, enemies, effects, tiles
- **audio/** - Music, SFX
- **fonts/** - UI fonts

### `/resources/`
Contains Godot resource files (.tres)

- **weapon_data/** - Weapon stats and configurations
- **loot_data/** - Loot definitions and drop tables

## Naming Conventions

- **Scenes:** PascalCase (e.g., `Player.tscn`, `BloodDagger.tscn`)
- **Scripts:** snake_case (e.g., `player.gd`, `blood_dagger.gd`)
- **Resources:** snake_case (e.g., `blood_dagger_stats.tres`)
- **Assets:** snake_case (e.g., `player_sprite.png`)

## Development Order (MVP)

1. Player movement + basic attack
2. Enemy spawning + basic AI
3. Weapon system (1 weapon to start)
4. Loot drops + inventory
5. Extraction point
6. Level-up system
