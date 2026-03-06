# Stormhold

Single-zone action RPG vertical slice built with [Forge tools](https://github.com/Amerzel/Forge) and Godot 4.x.

## Overview

A knight explores a goblin-infested forest clearing, fights through trash mobs,
survives an elite troll encounter, and defeats the Goblin Shaman boss. All game
data — entities, combat stats, encounters, quests, terrain — comes from the Forge
pipeline. Nothing is hardcoded.

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
│   └── systems/               # HUD, camera, input
├── scenes/                    # .tscn scene files
│   ├── main.tscn
│   ├── player/
│   ├── enemies/
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
