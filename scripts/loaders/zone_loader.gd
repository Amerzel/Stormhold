extends Node2D
## Loads a zone from Forge pack data and spawns all encounters.

const TILE_SIZE := 32

@export var zone_id: String = "stormhold-clearing"

var encounter_nodes: Array[Node2D] = []

func _ready() -> void:
_spawn_encounters()

func _spawn_encounters() -> void:
for enc in GameData.encounters:
var pos: Dictionary = enc.get("data", {}).get("position", {})
var x: float = pos.get("x", 0) * TILE_SIZE
var y: float = pos.get("y", 0) * TILE_SIZE
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
# Placeholder: spawn a colored rectangle until real scenes are ready
var enemy_scene := preload("res://scenes/enemies/base_enemy.tscn")
var enemy := enemy_scene.instantiate()
enemy.entity_data = entity
# Random offset within encounter radius
var offset := Vector2(randf_range(-radius, radius), randf_range(-radius, radius)) * TILE_SIZE
enemy.position = offset
parent.add_child(enemy)
