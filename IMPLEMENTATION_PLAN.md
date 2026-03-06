# IMPLEMENTATION_PLAN.md — Stormhold Build Guide

Step-by-step implementation plan for building the Stormhold vertical slice.
Each phase builds on the previous one. Complete each phase before moving to the next.

## Prerequisites

- Godot 4.4+ installed on Windows
- Tiny Swords asset pack (copy sprites into art/)
  - Base pack: Factions/, Terrain/, Deco/, Effects/, UI/
  - Enemy Pack: Bear, Spider, Troll, Shaman, etc.
- This repo cloned to C:\Dev\Game\projects\Stormhold

---

## Phase 1: Art Setup and Scene Foundation

**Goal:** Player can walk around a colored tile map.

### 1.1 Import Sprites
- Copy Tiny Swords sprites into art/:
  - art/characters/player/ from Factions/Knights/Troops/Warrior/Blue/
  - art/characters/enemies/goblin-grunt/ from Factions/Goblins/Troops/Torch/
  - art/characters/enemies/goblin-bomber/ from Factions/Goblins/Troops/TNT/
  - art/characters/enemies/spider/ from Enemy Pack/Spider/
  - art/characters/enemies/troll/ from Enemy Pack/Troll/
  - art/characters/enemies/shaman/ from Enemy Pack/Shaman/
  - art/terrain/ from Terrain/Ground/

### 1.2 Create Player Scene (scenes/player/player.tscn)
- CharacterBody2D root
- AnimatedSprite2D with Warrior spritesheet
- CollisionShape2D (capsule, ~12x16 px)
- Physics layer 1 (player), mask layers 2,3 (enemies, environment)
- Script: scripts/player/player.gd
  - 8-directional movement at GameData.player_class.data.movement_speed tiles/sec
  - Convert tiles/sec to pixels/sec: speed * 32
  - Camera2D child with smoothing

### 1.3 Create Main Scene (scenes/main.tscn)
- Node2D root
- TileMapLayer for terrain (use Tilemap_Flat.png as tileset)
  - Fill 80x60 area with grass tiles for now
- Spawn player at zone spawn_point from zone.v1.json (x:10, y:50 = 320px, 1600px)

### 1.4 Validation
- Run the game. Player walks around with WASD on a green field.
- Camera follows player. Movement speed feels right (~96 px/sec).

---

## Phase 2: Basic Combat

**Goal:** Player can attack enemies and kill them.

### 2.1 Create Base Enemy Scene (scenes/enemies/base_enemy.tscn)
- CharacterBody2D root
- AnimatedSprite2D
- CollisionShape2D
- HurtboxArea2D (Area2D for receiving damage)
- Script: scripts/enemies/base_enemy.gd
  - var entity_data: Dictionary (set by spawner)
  - HP from entity_data.data.stats.hp
  - Movement speed from entity_data.data.movement_speed
  - Takes damage, flashes red, dies when HP <= 0
  - On death: emit signal, call QuestManager.report_kill(entity_data.id)

### 2.2 Player Attack
- scripts/player/player_combat.gd (or extend player.gd)
- Left click: spawn attack hitbox in facing direction
- Hitbox is an Area2D, active for ~0.2s
- On overlap with enemy hurtbox: calculate damage via CombatManager
  - base_attack from equipped weapon (wpn-iron-sword: attack=8)
  - target_armor from enemy data (defense field)
- Attack cooldown: 1.0 / weapon_speed seconds

### 2.3 Spawn Enemies from Encounter Data
- Update zone_loader.gd to spawn base_enemy.tscn instances
- Read encounters.json, place at tile positions * 32
- Each enemy gets its entity_data from GameData.get_entity()
- Start with just Goblin Grunts (simplest)

### 2.4 Health Bars
- scenes/ui/health_bar.tscn: TextureProgressBar above entities
- Player health bar in HUD (top-left)
- Enemy health bars float above their heads

### 2.5 Validation
- Goblins appear at encounter positions. Player attacks them.
- Damage numbers make sense (8 atk vs 1 def = ~7.5 damage via formula).
- Goblins die after ~3 hits (25 HP / ~7.5 = 3.3). Quest counter updates.

---

## Phase 3: Enemy AI

**Goal:** Enemies fight back.

### 3.1 Goblin Grunt AI (melee-rusher)
- scripts/enemies/ai/melee_rusher.gd
- States: IDLE, CHASE, ATTACK, DEAD
- IDLE: stand still, check for player within aggro_range (6 tiles = 192px)
- CHASE: move toward player at movement_speed
- ATTACK: when within attack_range (1 tile), deal damage every attack_cooldown
- Player takes damage, health bar updates

### 3.2 Player Death
- When player HP <= 0: show death screen, restart option

### 3.3 Dodge Roll
- Space key: dash 4 tiles in movement direction
- Duration 0.3s, cooldown 1.0s
- Player is invincible during dash (disable hurtbox)

### 3.4 Validation
- Goblins chase and attack. Player can dodge. Combat feels like a game.

---

## Phase 4: Abilities and Status Effects

**Goal:** Player can use Q/E/R abilities. Status effects work.

### 4.1 Status Effect System
- scripts/systems/status_effect_system.gd
- Apply effect by ID: reads duration, stat_modifications, damage_per_tick from GameData
- Tick-based effects (Burning: 3 dmg/sec for 3s)
- Modifier effects (Battle Fury: 1.25x damage, 1.1x speed for 8s)
- Prevents effects (Stunned: prevents_movement + prevents_attack for 1.5s)

### 4.2 Ability System
- scripts/combat/ability_system.gd
- Each ability reads from GameData.get_ability_data()
- Cooldown tracking per ability
- Shield Bash (Q): 150% weapon damage in cone, applies sfx-stunned
- Whirlwind (E): 80% weapon damage to all in 2-tile radius
- Battle Cry (R): applies sfx-battle-fury to self

### 4.3 Ability HUD
- scenes/ui/ability_bar.tscn: 3 ability slots with cooldown overlays
- Shows key binding (Q/E/R) and remaining cooldown

### 4.4 Validation
- All 3 abilities work with correct damage/effects from data.
- Stunned enemies freeze. Battle Fury visibly increases damage output.

---

## Phase 5: Full Enemy Roster

**Goal:** All 5 enemy types implemented with unique behaviors.

### 5.1 Forest Spider (ambusher)
- Hidden until player within 3 tiles (alpha = 0 or burrowed sprite)
- Pops out, fast attack (0.8s cooldown), low HP

### 5.2 Goblin Bomber (ranged-kiter)
- Throws TNT at 4-tile range, 2s fuse (visible timer on ground)
- Flees when player within 2 tiles (flee_range)
- TNT is a scene: Area2D, timer, explosion AoE

### 5.3 Troll Brute (elite)
- Slow movement (1.5 tiles/sec), heavy damage
- Wind-up telegraph: 1s pause with visual indicator before each attack
- Recovery: after 3 swings, stunned for 2s (player's window to attack)
- Higher HP (120), drops good loot

### 5.4 Goblin Shaman Boss (phase-boss)
- Phase 1 (100%-40% HP):
  - Fires projectiles (fire bolts) at player, 6-tile range
  - Summons 2 Goblin Grunts every 15s
  - Projectile scene: move toward player position, deal damage + sfx-burning
- Phase 2 (below 40% HP):
  - Stops summoning
  - Explosion AoE every 8s (telegraph circle on ground, 2-tile radius)
  - Faster projectiles (1.5x speed)
- Boss health bar at top of screen

### 5.5 Validation
- Each enemy type behaves distinctly. Boss fight has two clear phases.
- Troll recovery window is exploitable. Spider ambush is surprising.

---

## Phase 6: Loot, Items, and Equipment

**Goal:** Enemies drop loot. Player can equip weapons and use potions.

### 6.1 Loot Drop System
- On enemy death: roll CombatManager.roll_loot() with enemy's loot_table_ref
- Spawn pickup nodes at death position (physics layer 5)
- scenes/pickups/loot_drop.tscn: Sprite + Area2D, auto-collect on player overlap

### 6.2 Inventory (Minimal)
- scripts/player/inventory.gd
- Weapon slot, armor slot, potion stack, gold counter
- Equipping a weapon changes player attack stat
- Equipping armor changes defense and HP bonus

### 6.3 Health Potion
- F key: consume 1 health potion, restore 40 HP (from con-health-potion data)
- Stack limit: 5

### 6.4 Validation
- Kill goblins, see gold and potions drop. Troll drops Troll-Hide Armor.
- Equipping Goblin Cleaver changes damage output. Potions heal correctly.

---

## Phase 7: Quest Tracker and Win Condition

**Goal:** Quest objectives display on screen. Beating the boss wins the game.

### 7.1 Quest HUD
- scenes/ui/quest_tracker.tscn: Panel in top-right
- Shows current objective text from QuestManager.get_current_objective_text()
- Updates on kill (QuestManager.objective_updated signal)
- Flashes on objective complete

### 7.2 Quest Flow
- Quest auto-starts on zone entry
- Phase 1: "Slay 5 goblins (0/5)" — any goblin type counts
- Phase 2: "Defeat the Troll Brute (0/1)"
- Phase 3: "Defeat the Goblin Shaman"

### 7.3 Win Screen
- On quest_completed signal: show victory panel
- Display: enemies killed, damage dealt, time elapsed
- "Play Again" button restarts the scene

### 7.4 XP and Leveling (Stretch Goal)
- Track XP from kills (xp_reward field on enemies)
- Level up at thresholds (from game_rules.json progression curves)
- Unlock abilities at levels 2 and 3

### 7.5 Validation
- Full playthrough: enter zone, kill goblins, kill troll, defeat shaman, win screen.
- All data comes from zone_packs/. Changing an entity's HP in the Forge pipeline
  and re-packing changes it in the game without touching GDScript.

---

## Entity Quick Reference

### Player (cls-warrior)
- HP: 210 | STR: 12 | AGI: 8 | INT: 5 | VIT: 10
- Speed: 3.0 tiles/sec | Attack range: 1.5 tiles
- Dodge: 4 tiles, 0.3s, 1.0s CD, invincible
- Starting gear: wpn-iron-sword (8 atk), arm-leather-vest (5 def, +10 HP)

### Enemies

| ID | HP | ATK | DEF | Speed | Range | Aggro | Behavior |
|----|-----|-----|-----|-------|-------|-------|----------|
| enm-goblin-grunt | 25 | 4 | 1 | 2.0 | 1.0 | 6.0 | melee-rusher |
| enm-goblin-bomber | 20 | 6 | 0 | 2.5 | 4.0 | 7.0 | ranged-kiter |
| enm-forest-spider | 18 | 5 | 0 | 3.5 | 1.0 | 3.0 | ambusher |
| enm-troll-brute | 120 | 12 | 6 | 1.5 | 1.5 | 8.0 | melee (elite) |
| enm-goblin-shaman | 200 | 8 | 3 | 1.8 | 6.0 | 10.0 | phase-boss |

### Abilities

| Name | Key | CD | Effect |
|------|-----|-----|--------|
| Shield Bash | Q | 6s | 150% dmg + 1.5s stun |
| Whirlwind | E | 10s | 80% dmg AoE 2 tiles |
| Battle Cry | R | 20s | +25% dmg, +10% speed 8s |

### Encounters (tile positions, multiply by 32 for pixels)

| Name | Position | Entities |
|------|----------|----------|
| Tutorial Goblins | (15,45) | 2x Goblin Grunt |
| Spider Ambush | (35,30) | 3x Forest Spider |
| Courtyard Patrol | (45,35) | 3x Grunt + 1x Bomber |
| Courtyard Camp | (55,20) | 2x Bomber + 2x Grunt |
| Troll Hollow | (25,15) | 1x Troll + 2x Grunt |
| Shaman Boss | (65,10) | 1x Goblin Shaman |

### Loot Tables

| Context | Drops |
|---------|-------|
| Goblin (common) | 70% gold(2-4), 20% health potion, 10% nothing |
| Troll (elite) | 100% gold(8-15), 40% troll-hide armor, 30% potion x2, 30% fire bomb |
| Shaman (boss) | 100% gold(25-40), 100% Shaman's Bane sword, 50% fire bomb x3 |

---

## Updating Game Data

If entity stats, encounters, or quests change in the Forge workspace:

```bash
# From WSL:
cd ~/work/gamedev/projects/Stormhold
./scripts/pack-for-godot.sh /mnt/c/Dev/Game/projects/Stormhold
```

Then restart the Godot game — GameData reloads everything from zone_packs/.
