extends Node
## Autoload: Combat calculations driven by Forge rules data.

const ARMOR_K := 120.0
const CRIT_MULTIPLIER := 1.8

func calculate_physical_damage(base_attack: float, weapon_mod: float, target_armor: float) -> float:
	var mitigation := target_armor / (target_armor + ARMOR_K)
	return base_attack * weapon_mod * (1.0 - mitigation)

func calculate_crit_damage(base_damage: float) -> float:
	return base_damage * CRIT_MULTIPLIER

func calculate_ability_damage(base_attack: float, weapon_mod: float, ability_multiplier: float, target_armor: float) -> float:
	var raw := base_attack * weapon_mod * ability_multiplier
	var mitigation := target_armor / (target_armor + ARMOR_K)
	return raw * (1.0 - mitigation)

func calculate_dot_damage(damage_per_tick: float) -> float:
	return damage_per_tick

func roll_crit(crit_chance: float = 0.1) -> bool:
	return randf() < crit_chance

func roll_loot(loot_table: Dictionary) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if not loot_table.has("entries"):
		return drops

	for entry in loot_table["entries"]:
		if randf() <= float(entry.get("drop_rate", 0.0)):
			var count_range: Array = entry.get("count_range", [1, 1])
			var count := randi_range(int(count_range[0]), int(count_range[1]))
			if count > 0 and entry.get("item_ref", "nothing") != "nothing":
				drops.append({
					"item_ref": entry["item_ref"],
					"count": count
				})

	return drops
