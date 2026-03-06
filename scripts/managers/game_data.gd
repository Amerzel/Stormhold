extends Node
## Autoload: Loads and serves all game data from Forge tool zone packs.
## All game entities, encounters, quests, and terrain come from JSON files
## in zone_packs/ — nothing is hardcoded.

var zone_data: Dictionary = {}
var entities: Dictionary = {}
var encounters: Array = []
var quest_data: Dictionary = {}
var player_class: Dictionary = {}
var combat_rules: Dictionary = {}

const TILE_SIZE := 32
const ZONE_PACK_PATH := "res://zone_packs/"

func _ready() -> void:
_load_zone("stormhold-clearing")
print("[GameData] Loaded %d entities, %d encounters" % [entities.size(), encounters.size()])

func _load_zone(zone_id: String) -> void:
var pack_path := ZONE_PACK_PATH + zone_id + "/"

# Zone spec
zone_data = _load_json(pack_path + "zone.v1.json")

# Entity catalog
var catalog := _load_json(pack_path + "entities/entity_catalog.json")
if catalog.has("entities"):
for entity in catalog["entities"]:
entities[entity["id"]] = entity

# Player class
if entities.has("cls-warrior"):
player_class = entities["cls-warrior"]

# Encounters
var enc_data := _load_json(pack_path + "encounters/encounters.json")
if enc_data.has("encounters"):
encounters = enc_data["encounters"]

# Quest
quest_data = _load_json(pack_path + "quests/quests.json")

# Combat rules
combat_rules = _load_json(pack_path + "game_rules.json")

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
return json.data if json.data is Dictionary else {}
