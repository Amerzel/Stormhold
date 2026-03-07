extends Area2D

@export var item_ref := ""
@export var count := 1

@onready var icon: Polygon2D = $Icon

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visual()

func configure(drop_item_ref: String, drop_count: int) -> void:
	item_ref = drop_item_ref
	count = drop_count
	if is_node_ready():
		_apply_visual()

func _on_body_entered(body: Node) -> void:
	if body.has_method("collect_loot"):
		body.collect_loot(item_ref, count)
		queue_free()

func _apply_visual() -> void:
	var color := Color(0.95, 0.86, 0.28, 1.0)
	if item_ref == "con-health-potion":
		color = Color(0.84, 0.18, 0.22, 1.0)
	elif item_ref.begins_with("wpn-"):
		color = Color(0.80, 0.80, 0.88, 1.0)
	elif item_ref.begins_with("arm-"):
		color = Color(0.52, 0.74, 0.48, 1.0)
	elif item_ref == "con-fire-bomb":
		color = Color(0.90, 0.48, 0.14, 1.0)

	icon.color = color
