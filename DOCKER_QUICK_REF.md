# Vampire Raiders - Docker Quick Reference

## 🚀 Start Everything (Easiest)

### Windows:
```bash
start-docker.bat
```

### Mac/Linux:
```bash
chmod +x start-docker.sh
./start-docker.sh
```

### Manual (All Platforms):
```bash
docker-compose up --build
```

---

## 📋 Common Commands

### View Logs
```bash
# Backend logs
docker-compose logs -f java-backend

# Database logs  
docker-compose logs -f mysql

# Both services
docker-compose logs -f
```

### Stop Services
```bash
docker-compose down
```

### Stop and Clean Everything (Fresh Start)
```bash
docker-compose down -v
```

### Rebuild After Code Changes
```bash
docker-compose up --build
```

### Check Status
```bash
docker-compose ps
```

### Restart Only Backend
```bash
docker-compose restart java-backend
```

---

## 🎮 Connecting from Godot

1. Open Godot project: `poc-godot/poc-vampire-raiders-multiplayer/project.godot`
2. Run the scene (F5)
3. Click "Start Client"
4. Enter server IP: `localhost` (or your machine's IP for LAN)
5. Click "Connect"

---

## 🌐 Network Testing

### Same Machine
```
localhost:7777
```

### Local Network (Same WiFi)
```
YOUR_MACHINE_IP:7777
```

Find your IP:
- **Windows**: `ipconfig` → look for IPv4 Address
- **Mac/Linux**: `ifconfig` → look for inet

---

## 🔧 Troubleshooting

### Port Already in Use
Edit `docker-compose.yml` and change the port:
```yaml
ports:
  - "7778:7777"  # Use 7778 instead
```

### Connection Refused
Make sure services are running:
```bash
docker-compose ps
```

Should show both containers as "Up"

### Database Not Ready
Check if MySQL is healthy:
```bash
docker-compose logs mysql
```

It may need 10-30 seconds to initialize.

### Build Fails
Ensure you have enough disk space and Docker memory (at least 2GB).

---

## 📦 Docker Compose Structure

```
docker-compose.yml
├── MySQL Service
│   ├── Port: 3306
│   ├── Database: vampire_raiders
│   ├── User: game_user / gamepassword
│   └── Init: database/init.sql
│
└── Java Backend Service
    ├── Port: 7777
    ├── Waits for MySQL to be healthy
    ├── Auto-builds with Maven
    └── Auto-restarts on failure
```

---

## 🐳 Docker Images

- **MySQL**: `mysql:8.0`
- **Java Build**: `maven:3.9-eclipse-temurin-25`
- **Java Runtime**: `eclipse-temurin:25-jre`

---

## 📝 Notes for Friends

Just tell them to:

1. Install Docker Desktop
2. Run `start-docker.bat` (or `.sh` on Mac/Linux)
3. Wait for "Backend is running" message
4. Open Godot and connect to your machine's IP

No Java, Maven, or MySQL install needed! 🎉

---

## 🆘 Need Help?

Check the full guide: `DOCKER_SETUP.md`
