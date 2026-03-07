# Stormhold

Single-zone action RPG vertical slice built with [Forge tools](https://github.com/Amerzel/Forge) and Godot 4.x.

## Overview

A knight explores a goblin-infested forest clearing, fights through trash mobs,
survives an elite troll encounter, and defeats the Goblin Shaman boss. All game
data — entities, combat stats, encounters, quests, terrain — comes from the Forge
pipeline. Nothing is hardcoded.

Current slice features include runtime-loaded sprite animation, enemy ranged
projectiles/telegraphs, a boss health bar, quest and loot notifications, player
XP/level tracking, capped potion stacks from live item data, and a pause overlay
that doubles as a quick run-status panel.

## Architecture

```
Forge Tools (WSL)                    Godot Project (Windows)
┌─────────────────────┐             ┌─────────────────────────┐
│ ForgeEntity (23)    │             │ zone_packs/             │
│ ForgeQuest (1)      │──pack──────►│   stormhold-clearing/   │
│ ForgeEncounter (6)  │             │     entity_catalog.json  │
│ ForgeRules          │             │     encounters.json      │
│ ForgeTerrain        │             │     quests.json          │
└─────────────────────┘             │     game_rules.json      │
                                    │                         │
                                    │ scripts/managers/       │
                                    │   game_data.gd (loader) │
                                    │   combat_manager.gd     │
                                    │   quest_manager.gd      │
                                    └─────────────────────────┘
```

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Left Click | Attack |
| Space | Dodge Roll |
| Q | Ability 1 (Shield Bash) |
| E | Ability 2 (Whirlwind) |
| R | Ability 3 (Battle Cry) |
| F | Use Health Potion |
| Esc | Pause / Review controls |

## Running the game

- `Run-Stormhold.bat` launches the playable window.
- `Run-Stormhold-Console.bat` launches the console build for debugging startup/runtime issues.
- If Godot is installed in a non-default location, set `GODOT_EXE` before launching one of the batch files.

## Quick review checklist

- Kill enemies to verify XP gain, level-ups, loot drops, HUD notifications, and potion stack caps.
- Press `Esc` to pause and inspect current run stats.
- Reach the Goblin Shaman to confirm the boss health bar appears at the top of the screen.
- Clear goblins -> troll -> shaman to confirm quest progression, the victory screen, and end-of-run stats.
- Use `Run-Stormhold-Console.bat` if you want startup/runtime logs while testing.

## Updating Game Data

Game data is packed from the Forge workspace (WSL) to this project:

```bash
# From the Forge workspace in WSL:
cd projects/Stormhold
./scripts/pack-for-godot.sh /mnt/c/Dev/Game/projects/Stormhold
```

This exports all entity, encounter, quest, and combat data as JSON into
`zone_packs/stormhold-clearing/`. The Godot project reads these at runtime
via the `GameData` autoload.

## Project Structure

```
Stormhold/
├── project.godot              # Godot config (inputs, autoloads, physics layers)
├── zone_packs/                # Forge pipeline output (DO NOT EDIT BY HAND)
│   └── stormhold-clearing/
│       ├── manifest.json
│       ├── zone.v1.json
│       ├── game_rules.json
│       ├── terrain/
│       ├── entities/
│       ├── encounters/
│       └── quests/
├── scripts/
│   ├── managers/              # Autoloads: GameData, CombatManager, QuestManager
│   ├── loaders/               # Zone/entity loading from pack data
│   ├── player/                # Player controller, abilities, inventory
│   ├── enemies/               # Enemy AI, behavior implementations
│   ├── combat/                # Damage, status effects, loot
│   ├── projectiles/           # Enemy projectile and telegraph scenes/scripts
│   └── systems/               # Shared gameplay systems
├── scenes/                    # .tscn scene files
│   ├── main.tscn
│   ├── player/
│   ├── enemies/
│   ├── projectiles/
│   ├── ui/
│   └── zones/
└── art/                       # Tiny Swords sprites
    ├── characters/
    ├── terrain/
    └── ui/
```

## Design Document

See `projects/Stormhold/PROTOTYPE.md` in the [Forge workspace](https://github.com/Amerzel/Forge)
for the full game design specification.
