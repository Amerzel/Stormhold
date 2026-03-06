extends Node2D
## Loads a zone from Forge pack data and spawns all encounters.

@export var zone_id: String = "stormhold-clearing"

var encounter_nodes: Array[Node2D] = []

func _ready() -> void:
	randomize()
	_spawn_encounters()

func _spawn_encounters() -> void:
	var tile_size := GameData.get_tile_size()
	for enc in GameData.encounters:
		var pos: Dictionary = enc.get("data", {}).get("position", {})
		var x: float = pos.get("x", 0) * tile_size
		var y: float = pos.get("y", 0) * tile_size
		var entity_refs: Array = enc.get("data", {}).get("entity_refs", [])

		var encounter_node := Node2D.new()
encounter_node.name = enc.get("id", "encounter")
encounter_node.position = Vector2(x, y)
add_child(encounter_node)
encounter_nodes.append(encounter_node)

for ref in entity_refs:
var entity_id: String = ref.replace("ea:", "")
var entity := GameData.get_entity(entity_id)
if entity.get("category") == "enemy":
_spawn_enemy(encounter_node, entity, enc.get("data", {}).get("radius", 4))

func _spawn_enemy(parent: Node2D, entity: Dictionary, radius: float) -> void:
	var enemy_scene := preload("res://scenes/enemies/base_enemy.tscn")
	var enemy := enemy_scene.instantiate()
	enemy.entity_data = entity
	var offset := Vector2(randf_range(-radius, radius), randf_range(-radius, radius)) * GameData.get_tile_size()
	enemy.position = offset
	parent.add_child(enemy)
