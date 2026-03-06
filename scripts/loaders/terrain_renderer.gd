extends Node2D

const FALLBACK_TILE_SIZE := 32.0

var _base_layer: Array = []
var _tile_lookup: Dictionary = {}
var _map_width := 0
var _map_height := 0
var _tile_size := FALLBACK_TILE_SIZE

func _ready() -> void:
	var terrain: Dictionary = GameData.terrain_data
	if terrain.is_empty():
		push_warning("Terrain data is missing for the active zone.")
		return

	_map_width = int(terrain.get("width", 0))
	_map_height = int(terrain.get("height", 0))
	_tile_size = float(terrain.get("tileSize", GameData.get_tile_size()))
	_tile_lookup.clear()
	_base_layer.clear()

	for entry in terrain.get("tileLookup", []):
		_tile_lookup[int(entry.get("id", -1))] = entry

	for layer in terrain.get("layers", []):
		if layer.get("name", "") == "base":
			_base_layer = layer.get("data", [])
			break

	queue_redraw()

func _draw() -> void:
	if _base_layer.is_empty() or _map_width <= 0 or _map_height <= 0:
		return

	for index in _base_layer.size():
		var tile_x := index % _map_width
		var tile_y := int(index / _map_width)
		var tile_metadata: Dictionary = _tile_lookup.get(int(_base_layer[index]), {})
		var tile_rect := Rect2(
			tile_x * _tile_size,
			tile_y * _tile_size,
			_tile_size,
			_tile_size
		)
		draw_rect(tile_rect, _get_tile_color(tile_metadata), true)

func _get_tile_color(tile_metadata: Dictionary) -> Color:
	match tile_metadata.get("material", ""):
		"grass":
			return Color(0.25, 0.50, 0.24)
		"stone":
			return Color(0.48, 0.48, 0.52)
		"dark_grass":
			return Color(0.18, 0.32, 0.18)
		"water":
			return Color(0.18, 0.36, 0.67)
		"tree":
			return Color(0.14, 0.22, 0.12)
		_:
			return Color(0.30, 0.30, 0.30)
