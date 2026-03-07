extends Node
## Autoload: Loads and serves all game data from Forge tool zone packs.
## All game entities, encounters, quests, and terrain come from JSON files
## in zone_packs/ - nothing is hardcoded.

var zone_data: Dictionary = {}
var entities: Dictionary = {}
var encounters: Array = []
var quest_data: Dictionary = {}
var player_class: Dictionary = {}
var combat_rules: Dictionary = {}
var terrain_data: Dictionary = {}
var behavior_trees: Dictionary = {}

const TILE_SIZE := 32
const ZONE_PACK_PATH := "res://zone_packs/"

func _ready() -> void:
	_load_zone("stormhold-clearing")
	print("[GameData] Loaded %d entities, %d encounters" % [entities.size(), encounters.size()])

func _load_zone(zone_id: String) -> void:
	var pack_path := ZONE_PACK_PATH + zone_id + "/"

	zone_data = _load_json(pack_path + "zone.v1.json")

	var catalog := _load_json(pack_path + "entities/entity_catalog.json")
	entities.clear()
	if catalog.has("entities"):
		for entity in catalog["entities"]:
			entities[entity["id"]] = entity

	player_class = entities.get("cls-warrior", {})

	var enc_data := _load_json(pack_path + "encounters/encounters.json")
	encounters = enc_data.get("encounters", [])

	quest_data = _load_json(pack_path + "quests/quests.json")
	combat_rules = _load_json(pack_path + "game_rules.json")
	terrain_data = _load_json(pack_path + "terrain/resolved.v1.json")
	behavior_trees.clear()
	_load_behavior_trees(pack_path + "behaviors/")

func get_entity(id: String) -> Dictionary:
	if entities.has(id):
		return entities[id]
	push_warning("Entity not found: " + id)
	return {}

func get_enemy_data(id: String) -> Dictionary:
	var entity := get_entity(id)
	if entity.is_empty() or entity.get("category") != "enemy":
		return {}
	return entity.get("data", {})

func get_weapon_data(id: String) -> Dictionary:
	var entity := get_entity(id)
	if entity.is_empty() or entity.get("category") != "weapon":
		return {}
	return entity.get("data", {})

func get_ability_data(id: String) -> Dictionary:
	var entity := get_entity(id)
	if entity.is_empty() or entity.get("category") != "ability":
		return {}
	return entity.get("data", {})

func get_status_effect(id: String) -> Dictionary:
	var entity := get_entity(id)
	if entity.is_empty() or entity.get("category") != "status_effect":
		return {}
	return entity.get("data", {})

func get_loot_table(id: String) -> Dictionary:
	var entity := get_entity(id)
	if entity.is_empty() or entity.get("category") != "loot_table":
		return {}
	return entity.get("data", {})

func get_behavior_tree(id: String) -> Dictionary:
	if behavior_trees.has(id):
		return behavior_trees[id]
	return {}

func get_tile_size() -> int:
	return int(terrain_data.get("tileSize", TILE_SIZE))

func get_zone_dimensions() -> Vector2i:
	var dimensions: Dictionary = zone_data.get("dimensions", {})
	return Vector2i(
		int(dimensions.get("width", 0)),
		int(dimensions.get("height", 0))
	)

func get_spawn_world_position() -> Vector2:
	var spawn_point: Dictionary = zone_data.get("spawn_point", {})
	var tile_size := float(get_tile_size())
	return Vector2(
		float(spawn_point.get("x", 0.0)) * tile_size,
		float(spawn_point.get("y", 0.0)) * tile_size
	)

func get_progression_constant(key: String, default_value: float = 0.0) -> float:
	var constants: Dictionary = combat_rules.get("progression", {}).get("constants", {})
	var value = constants.get(key, default_value)
	if value is Dictionary:
		return float(value.get("value", default_value))
	return float(value)

func get_level_cap() -> int:
	return int(get_progression_constant("level_cap", 1.0))

func get_xp_required_for_level(level: int) -> int:
	var formulas: Dictionary = combat_rules.get("progression", {}).get("formulas", {})
	var xp_formula: Dictionary = formulas.get("xp_reward", {})
	var expression := String(xp_formula.get("expression", ""))
	var exponent := 1.0
	if expression.contains("^"):
		var exponent_parts := expression.split("^")
		if exponent_parts.size() > 1:
			exponent = float(String(exponent_parts[1]).strip_edges())
	var xp_base := get_progression_constant("xp_base", 1.0)
	return max(1, roundi(xp_base * pow(max(level, 1), exponent)))

func calculate_character_max_hp(vitality: int) -> float:
	var base_hp := get_progression_constant("base_hp", 0.0)
	var hp_per_vitality := get_progression_constant("hp_per_vitality", 0.0)
	return base_hp + float(vitality) * hp_per_vitality

func get_enemy_xp_reward(entity_id: String) -> int:
	var enemy := get_entity(entity_id)
	return int(enemy.get("data", {}).get("xp_reward", 0))

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: " + path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}

	if json.data is Dictionary:
		return json.data
	return {}

func _load_behavior_trees(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue

		var tree := _load_json(path + file_name)
		var entity_ref: String = String(tree.get("entityId", ""))
		if entity_ref.begins_with("ea:"):
			entity_ref = entity_ref.trim_prefix("ea:")
		if not entity_ref.is_empty():
			behavior_trees[entity_ref] = tree
