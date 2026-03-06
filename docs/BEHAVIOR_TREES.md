# Behavior Trees — Implementation Notes

Five behavior trees are packed in `zone_packs/stormhold-clearing/behaviors/`, one per enemy.
These are **structural blueprints**, not drop-in AI. They define decision priority but not
timing, movement, or animation. This document explains what to use, what to ignore, and
what to wire up yourself.

---

## Tree Summary

| Enemy | File | Archetype | Status |
|-------|------|-----------|--------|
| Goblin Grunt | `enm-goblin-grunt.bt.json` | pack-predator | ✅ Use as-is |
| Troll Brute | `enm-troll-brute.bt.json` | pack-predator | ⚠ Tune for heavy/slow |
| Forest Spider | `enm-forest-spider.bt.json` | ambusher | ✅ Use as-is |
| Goblin Shaman | `enm-goblin-shaman.bt.json` | phase-boss | ✅ Use as-is |
| Goblin Bomber | `enm-goblin-bomber.bt.json` | pack-predator | ❌ **Wrong tree — see below** |

---

## ❌ Goblin Bomber: Ignore the Tree

The bomber's entity data specifies `behavior_archetype: "ranged-kiter"` with `attack_range: 4`
and `flee_range: 2`, but ForgeBehavior doesn't have a ranged-kiter archetype yet. It fell back
to pack-predator (melee rush), which is completely wrong for this enemy.

**Implement the bomber AI manually:**
- Maintain distance from player (keep 3-4 tiles away)
- If player gets within `flee_range` (2 tiles), disengage and reposition
- Use `abl-bomb-throw` ability at range (attack_cooldown: 2s)
- Flee at low HP like other enemies

---

## Wiring Trees to Entity Data

The trees use abstract conditions (`TargetInMeleeRange`, `IsHPLow`, etc.) that need
concrete values from the entity catalog. Here's the mapping:

| Tree Condition | Entity Field | Example (Goblin Grunt) |
|---------------|-------------|----------------------|
| `TargetDetected` | `data.aggro_range` | 6 tiles |
| `TargetInMeleeRange` | `data.attack_range` | 1 tile |
| `IsHPLow` | Flee threshold | 20% of `data.stats.hp` |
| `TargetFar` (shaman) | > `data.attack_range` | Custom per phase |

| Tree Action | Entity Field | Notes |
|------------|-------------|-------|
| `Flee` | `data.movement_speed × 1.5` | Speed boost while fleeing |
| `Chase` | `data.movement_speed` | Normal move speed (tiles/sec) |
| `Attack` | `data.attack_cooldown` | Seconds between hits |
| `Patrol` | Encounter position + radius | From encounters data |

---

## Per-Enemy Implementation Notes

### Goblin Grunt (pack-predator)
- **Priority:** flee → attack → chase → patrol → idle
- `CoordinateWithPack` + `AlertPack`: when one grunt detects player, all grunts in the
  same encounter should aggro. Implement via a shared alert signal on the encounter group.
- Stats: 25 HP, 4 ATK, speed 2.5, aggro 6, melee range 1, cooldown 1s

### Troll Brute (pack-predator)
- Same tree structure as grunt, but should **feel different**:
  - Slower movement (speed 2.0 vs 2.5)
  - Longer attack windup (cooldown 2.5s) — telegraph the hit
  - Higher damage (8 ATK) and much more HP (80)
  - `CoordinateWithPack` is less relevant — troll is usually solo or with goblins.
    Treat it as "troll aggros independently."
- Stats: 80 HP, 8 ATK, 3 DEF, speed 2.0, aggro 5, melee range 1.5, cooldown 2.5s

### Forest Spider (ambusher)
- **Priority:** retreat → ambush strike → melee combat → find hiding spot → wait
- `IsHidden` / `Hide` / `FindHidingSpot`: spider starts invisible (`hidden_until_aggro: true`).
  Implement as a stealth state — spider is invisible until player enters aggro range (3 tiles),
  then ambush strike for bonus damage.
- After retreat, spider should try to re-hide if possible.
- Stats: 18 HP, 5 ATK, speed 3.5 (fast), aggro 3 (short), melee range 1, cooldown 0.8s

### Goblin Shaman — Boss (phase-boss)
- **Three HP-based phases:**
  - **Phase 1 (100-60% HP):** Melee combo + dash if player is far
  - **Phase 2 (60-30% HP):** Ranged attacks, summon minions, AoE blast (with cooldowns)
  - **Phase 3 (below 30% HP):** Enrage buff, dash strikes, frenzied melee
- `SummonMinions`: spawn 2 goblin grunts (use grunt entity data). Suggest max 4 active summons.
- `AoEBlast`: use `abl-dark-bolt` ability data for damage/range.
- `EnrageBuff`: apply `eff-rallied` status effect (+25% damage).
- Decorators (`SummonCooldown`, `AoECooldown`, `DashCooldown`) need actual cooldown values —
  suggest 8s for summon, 5s for AoE, 3s for dash.
- Stats: 150 HP, 6 ATK, 2 DEF, speed 2.0, aggro 8, range 1, cooldown 1.5s

---

## What the Trees Don't Cover

These are implementation-side concerns, not design data:

| Aspect | Notes |
|--------|-------|
| Attack animations | Duration, windup frames, hit frame timing |
| Stagger/hitstun | How enemies react to being hit mid-action |
| Pathfinding | How enemies navigate around obstacles |
| Leashing | How far enemies chase before giving up (suggest 2× aggro range) |
| Respawn | Whether/when enemies respawn after death |
| Death animation | Duration before corpse disappears |
| Aggro transfer | How threat works with multiple targets (N/A for single player) |

---

## File Format Reference

Each `.bt.json` file has this structure:

```json
{
  "root": {
    "type": "selector|sequence|condition|action|decorator",
    "name": "NodeName",
    "params": {},
    "children": []
  }
}
```

- **selector**: tries children left-to-right, succeeds on first success
- **sequence**: runs children left-to-right, fails on first failure
- **condition**: evaluates a boolean (e.g., `IsHPLow`)
- **action**: executes behavior (e.g., `Attack`, `Flee`)
- **decorator**: wraps a child with a modifier (e.g., cooldown timer)
