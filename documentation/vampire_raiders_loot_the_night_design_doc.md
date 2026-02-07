# Vampire Raiders — Loot the Night

## High Concept
**Vampire Raiders** is a co-op survival–extraction game that blends the power-fantasy chaos of *Vampire Survivors* with the risk–reward tension of extraction games like *ARC Raiders*.

> *Drop in weak, grow absurdly powerful, loot the night, and escape before the chaos takes it back.*

---

## Core Design Pillar
**Split Power Across Two Timelines**

- **Run Power (Temporary)**
  - Level-ups
  - Weapons & evolutions
  - Passives
  - Resets every run

- **Account Power (Persistent)**
  - Unlocks
  - Modifiers
  - Loot-based progression
  - No raw combat power extracted

---

## Core Gameplay Loop
1. Spawn weak with a basic auto-attack
2. Kill hordes → level up rapidly
3. Grow absurdly strong
4. Loot valuable items that take inventory space
5. Decide: *stay longer or extract now*
6. Escape with loot or die and drop it

A successful run is defined by **extracting meaningful loot**, not surviving for a fixed time.

---

## Sample Run (10–15 Minutes)

### Minute 0–2 — Drop In
- One starter weapon
- Fast early level-ups
- Low enemy density
- Loot: Blood Vials, Relic Fragments

### Minute 3–6 — Power Curve
- Elite enemies appear
- Inventory begins to fill
- Loot starts applying penalties

### Minute 7 — Extraction Opens
- Extraction points appear
- Activating one spawns a mini-boss
- Enemies converge on exit

### Minute 8–12 — Greed Phase
- Maximum chaos
- Rare and cursed loot appears
- Enemy density and hazards increase

### Minute 12–15 — Escape or Die
- Countdown-based extraction
- Teammates can cover escape
- Loot secured only on successful extraction

---

## Combat System (Vampire Survivors DNA)

### Starter Weapons

**Blood Daggers**
- Random-direction projectiles
- Fast, low damage
- Scales with projectile count and pierce

*Evolution: Crimson Storm*
- Orbiting daggers with bleed trails

---

**Bat Swarm**
- Periodic homing bats
- Low DPS, high coverage

*Evolution: Night Cloud*
- Bats never despawn
- Area slowly fills with bats

---

**Blood Nova**
- AoE pulse around player
- Cooldown-based

*Evolution: Scarlet Cataclysm*
- Each kill triggers a mini-nova

---

### Passives (Shared Pool)
- Move Speed
- Pickup Radius
- Cooldown Reduction
- Lifesteal
- Max HP

All combat upgrades are **run-only**.

---

## Loot & Inventory System (Extraction Layer)

### Inventory Rules
- Limited slots (e.g. 6)
- Some items occupy multiple slots
- Heavy or cursed loot applies penalties
- Loot is dropped on death

### Loot Categories

**Common**
- Blood Vials
- Relic Shards

**Rare**
- Ancient Runes
- Weapon Unlock Tokens

**Cursed**
- Forbidden Relics
- Contracts
- High risk / high reward

---

### Cursed Loot Examples

**Blood Idol**
- Worth 5× normal loot
- Enemy spawn rate +30%
- Elite spawn chance +10%

**Eye of the Night**
- Reveals all exits
- Marks carrier on map
- Cannot extract for 90 seconds

**Blood Contract**
- Kill 500 enemies before extraction
- Success: guaranteed rare unlock
- Failure: lose all carried loot

---

## Extraction System
- Multiple extraction points per map
- Activating extraction:
  - Locks player into area
  - Spawns enemy waves
  - Triggers countdown

Only extracted loot contributes to progression.

---

## Multiplayer Design

### Recommended Mode: Co-op First
- 1–4 players
- Shared chaos
- No direct PvP

### Player Roles

| Role | Bonus |
|---|---|
| Cleaver | Increased AoE size |
| Collector | Bonus loot pickup radius |
| Scout | Increased movement speed |
| Blood Mage | Lifesteal / healing aura |

Only one player needs to extract with loot for team success.

---

## Meta Progression
Between runs, extracted loot is used to:
- Unlock new weapons
- Unlock new passives
- Bias level-up RNG
- Unlock harder zones with better loot

**Important Rule:**
> Players always start weak.

---

## PvPvE Consideration (Optional, Later)
If added:
- No direct player damage
- Players can contest extractions
- Players can steal dropped loot
- Players can lure enemies toward others

---

## Prototype Scope (MVP)

**One Map**
- Single biome

**Enemies**
- 1 basic enemy
- 1 elite
- 1 mini-boss

**Player Content**
- 6 weapons
- 6 passives
- 3 loot items
- 1 extraction point

Enough to validate the core loop.

---

## Technical Build Order
1. Single-player prototype
2. Combat feel & enemy density
3. Loot inventory system
4. Extraction system
5. Co-op multiplayer
6. Meta progression

> If it’s not fun solo, multiplayer won’t fix it.

---

## Elevator Pitch
*Vampire Raiders is a co-op survival–extraction game where players grow absurdly powerful, loot the night, and escape before the chaos overwhelms them.*
