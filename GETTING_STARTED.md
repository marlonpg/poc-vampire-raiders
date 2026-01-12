# 🧛 Vampire Raiders - Getting Started

Welcome to Vampire Raiders! This guide will get you and your friends playing in minutes.

## Quick Start (5 minutes)

### Step 1: Install Docker
Download and install **Docker Desktop**:
- https://www.docker.com/products/docker-desktop
- Takes ~2 minutes, restart your computer

### Step 2: Start the Server

From the project root (`poc-vampire-raiders/`):

**Windows:**
```bash
start-docker.bat
```

**Mac/Linux:**
```bash
chmod +x start-docker.sh
./start-docker.sh
```

**Or manually (all platforms):**
```bash
docker-compose up --build
```

### Step 3: Wait for Server Ready
You'll see output ending with:
```
[NETWORK] Game loop started at 60 ticks/second
```

That means the server is ready! (Takes ~1-2 minutes first time)

### Step 4: Start Godot Client
1. Open: `poc-godot/poc-vampire-raiders-multiplayer/project.godot`
2. Press **F5** to run
3. Click **"Start Client"**
4. Enter: `localhost`
5. Click **"Connect"**

🎮 **You're in!**

#### Network mode (default)
- Inputs use UDP by default for lower latency; reliable actions (auth, inventory, equip/drop) stay on TCP.
- If you need to force TCP-only (e.g., debugging or a network blocks UDP), add the flag `--tcp-only` to the Godot run args.

---

## 🎮 Gameplay

- **WASD/Arrow Keys** - Move
- **Mouse Click** - Attack (auto-targets nearest enemy)
- **Drag Items** - Inventory (drag & drop into slots)
- **Red Numbers** - Damage you deal to enemies
- **Orange Numbers** - Damage enemies deal to you
- **ESC** - Return to main menu

---

## 👥 Playing with Friends

### Local Network (Same WiFi)
1. Find your machine's IP:
   - **Windows**: Open Command Prompt, type `ipconfig`, note IPv4 Address
   - **Mac/Linux**: Open Terminal, type `ifconfig`, note inet address

2. Share that IP with friends
3. They open Godot and use your IP instead of `localhost`

Example: `192.168.1.100:7777`

---

## 📁 Project Structure

```
poc-vampire-raiders/
├── docker-compose.yml              ← Runs everything
├── start-docker.bat                ← Quick start (Windows)
├── start-docker.sh                 ← Quick start (Mac/Linux)
├── DOCKER_SETUP.md                 ← Detailed Docker guide
├── DOCKER_QUICK_REF.md             ← Command reference
│
├── database/
│   ├── init.sql                   ← Database schema
│   └── docker-compose.yml         ← Old DB-only compose
│
├── java-backend/               ← Game Server
│   ├── Dockerfile                 ← Server container
│   ├── pom.xml                    ← Maven config
│   ├── src/                       ← Java source
│   ├── build.bat                  ← Manual build (not needed with Docker)
│   └── start.bat                  ← Manual start (not needed with Docker)
│
└── poc-godot/
    ├── poc-vampire-raiders-multiplayer/  ← Game Client (Godot 4)
    │   ├── project.godot          ← Open this in Godot
    │   ├── scenes/                ← Game scenes
    │   │   ├── ui/                ← UI scenes (menus, inventory, HUD)
    │   │   ├── gameplay/          ← Gameplay scenes (world, player, enemies)
    │   │   └── weapons/           ← Weapon scenes
    │   ├── scripts/               ← Game code
    │   │   ├── ui/                ← UI scripts
    │   │   ├── gameplay/          ← Gameplay scripts
    │   │   ├── network/           ← Network client code
    │   │   └── autoload/          ← Global singletons
    │   ├── assets/                ← Art, audio, fonts
    │   ├── resources/             ← Game data (items, loot tables)
    │   └── themes/                ← UI themes
    └── vampire-raiders/           ← Finished game (not used yet)
```
---

## 🐳 What Docker Does

Instead of manually installing:
- ✅ Java 25
- ✅ Maven
- ✅ MySQL
- ✅ All dependencies

---

## 💬 Notes for Friends

Just send them:

> 1. Download Docker Desktop: https://www.docker.com/products/docker-desktop
> 2. Download the Vampire Raiders project
> 3. Run `start-docker.bat` (Windows) or `./start-docker.sh` (Mac/Linux)
> 4. Open `poc-godot/poc-vampire-raiders-multiplayer/project.godot` in Godot
> 5. Press F5, click "Start Client", enter my IP
> 6. Done! Play!