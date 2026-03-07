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
