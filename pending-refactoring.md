# Pending Refactoring (Godot 4)

## Recommended Structure (Godot 4)
- `addons/` (plugins)
- `assets/` (art, audio, fonts, VFX)
- `scenes/`
  - `ui/`
  - `gameplay/`
  - `characters/`
  - `levels/`
- `scripts/`
  - `autoload/` (Singletons: Global, EventBus, Config)
  - `ui/`
  - `gameplay/`
  - `characters/`
  - `network/`
  - `systems/` (combat, loot, inventory)
- `resources/` (tres/tres data, data-driven tables)
- `themes/` (tres theme files)
- `tests/` (unit/integration if used)
- `export_presets.cfg`
- `project.godot`

## Task Checklist
- [x] Create top-level folders per structure (assets, scenes/ui, scenes/gameplay, scripts/ui, scripts/gameplay, scripts/network, scripts/systems, scripts/autoload, resources, themes)
- [x] Move existing scenes into `scenes/` (main menu, world, inventory UI, enemies, items)
- [x] Move scripts to matching `scripts/` subfolders (ui, gameplay, network, systems)
- [x] Convert global helpers to autoload singletons (e.g., `GlobalAuth`, event bus, config)
- [x] Ensure damage numbers live under `scenes/ui/` with script in `scripts/ui/`
- [x] Centralize networking scripts under `scripts/network/` (bootstrap, network_manager, udp client)
- [ ] Group combat/inventory logic under `scripts/systems/` (CombatSystem, loot, equipment)
- [ ] Move data resources (items, weapons, loot tables) into `resources/`
- [ ] Consolidate themes into `themes/` and ensure UI scenes reference them
- [x] Add clear naming convention (PascalCase scenes, snake_case nodes, lower_snake scripts)
- [x] Update preload/load paths after moves
- [x] Run the game and fix any broken references after refactor
- [x] Add README section documenting layout and conventions

## Completed Changes
- ✅ Created organized folder structure following Godot 4 best practices
- ✅ Moved all UI scenes to `scenes/ui/` (MainMenu, LoginScreen, RegisterScreen, ResultScreen, InventoryUI, DamageNumber)
- ✅ Moved all gameplay scenes to `scenes/gameplay/` (World, Player, Enemy, Bullet, WorldItem)
- ✅ Reorganized scripts to match scene structure
- ✅ Updated all scene script references and preload paths
- ✅ Fixed autoload paths in project.godot (GlobalAuth, NetworkManager, Bootstrap)
- ✅ Fixed MainMenu.tscn parse error (missing root node declaration)
- ✅ Updated all scene navigation paths (change_scene_to_file)
- ✅ Fixed DamageNumber color display (player damage now shows orange)
- ✅ Verified all resource paths work correctly

## Current Inventory (poc-vampire-raiders-multiplayer)
- Scenes (root): Bullet, Enemy, InventoryUI, LoginScreen, MainMenu, Player, RegisterScreen, ResultScreen, World, WorldItem
- Scenes (ui): DamageNumber
- Scenes (weapons): IronDagger, SteelSword
- Scripts (root): bootstrap*, bootstrap_udp*, bullet, DamageNumber, enemy, EquipmentSlot, EquippedItemIcon, GlobalAuth, GridCell, grid_background, InventoryUI, ItemIcon, LoginScreen, MainMenu, network_manager, player, RegisterScreen, ResultScreen, udp_network_client, world, world_item (+ .uid files alongside)
- Missing folders: assets/, resources/, themes/, scripts subfolders, tests/

## Move Plan (proposed mappings)
- scenes/
  - ui/: DamageNumber.tscn, InventoryUI.tscn, LoginScreen.tscn, RegisterScreen.tscn, ResultScreen.tscn, MainMenu.tscn
  - gameplay/: World.tscn, WorldItem.tscn, Enemy.tscn, Player.tscn, Bullet.tscn
  - weapons/: keep IronDagger.tscn, SteelSword.tscn (or move under scenes/gameplay/weapons if preferred)
- scripts/
  - ui/: DamageNumber.gd, InventoryUI.gd, EquipmentSlot.gd, EquippedItemIcon.gd, ItemIcon.gd, LoginScreen.gd, RegisterScreen.gd, ResultScreen.gd, MainMenu.gd, grid_background.gd, GridCell.gd
  - gameplay/: player.gd, enemy.gd, bullet.gd, world_item.gd
  - network/: network_manager.gd, udp_network_client.gd, bootstrap.gd, bootstrap_udp.gd
  - systems/: (future) CombatSystem.gd, loot/equipment systems as they are split out of world/player
  - autoload/: GlobalAuth.gd (and future EventBus/Config)
- resources/: data tables, item/weapon resources, future loot tables
- themes/: existing and future `.tres` theme files
- tests/: placeholder for GUT or unit tests if added

## Path Update Notes
- Update preload/load paths in scenes and scripts after moves (e.g., `res://scripts/ui/...`)
- Rewire autoloads in `project.godot` when moving GlobalAuth and any new singletons
- Re-export weapon/resource paths if moved under scenes/gameplay/weapons or resources/
