# Vampire Raiders - Java Backend Server

This is the authoritative server implementation for the Vampire Raiders multiplayer game.

## Architecture

The server uses **ENet-style UDP networking** (simulated here with TCP sockets for simplicity) to handle multiple game clients. All game state is maintained on the server, ensuring security and consistency.

### Key Components

- **NetworkManager**: Handles client connections, disconnections, and message routing
- **GameWorld**: Manages game state (players, enemies, world bounds)
- **GameLoop**: Runs at configurable tick rate (default 60 Hz), updates world state and syncs to clients
- **SpawnerSystem**: Spawns enemies at regular intervals
- **StateSync**: Serializes game state to JSON for client synchronization
- **CombatSystem**: Handles damage, collisions, and XP rewards

## Building

```bash
mvn clean package
```

## Running

```bash
java -jar target/server-0.1.0.jar
```

Or run from IDE:
```bash
mvn exec:java -Dexec.mainClass="com.vampireraiders.VampireRaidersServer"
```

## Configuration

Edit `src/main/resources/application.properties`:

```properties
server.port=7777                    # Server port
server.host=0.0.0.0                 # Server host
game.tick-rate=60                   # Game updates per second
game.max-players=4                  # Maximum concurrent players
spawner.spawn-interval=5000         # Enemy spawn interval (ms)
spawner.max-enemies=10              # Max enemies in world
```

## Communication Protocol

### Client → Server Messages

```json
{
  "type": "player_join",
  "username": "Player1",
  "x": 640,
  "y": 360
}
```

```json
{
  "type": "player_input",
  "dir_x": 1.0,
  "dir_y": 0.0
}
```

### Server → Client Messages

```json
{
  "type": "game_state",
  "world_time": 1234,
  "players": [...],
  "enemies": [...]
}
```

## Server Workflow

1. **Client connects** → Server creates GameClient and Player instance
2. **Client sends input** → Server validates and updates Player velocity
3. **Game loop runs** → Updates positions, checks collisions, handles combat
4. **StateSync broadcasts** → All clients receive authoritative game state
5. **Client disconnects** → Server removes player from world

## Security

- Server validates all client input
- All damage/death calculations are server-side only
- Clients cannot modify their own positions or health directly
- Each client's input is tied to their peer ID for verification

## Future Enhancements

- [ ] UDP implementation with custom protocol
- [ ] Persistence layer for player stats
- [ ] Matchmaking system
- [ ] Chat system
- [ ] Admin commands
- [ ] Ban system
