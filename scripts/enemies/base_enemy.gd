extends CharacterBody2D

@export var entity_data: Dictionary = {}

@onready var health_bar: ProgressBar = $HealthBar
@onready var body: Polygon2D = $PlaceholderBody

var current_health := 0.0
var max_health := 0.0

func _ready() -> void:
	name = entity_data.get("id", "enemy")
	add_to_group("enemies")

	var stats: Dictionary = entity_data.get("data", {}).get("stats", {})
	max_health = float(stats.get("hp", 1.0))
	current_health = max_health
	health_bar.max_value = max_health
	health_bar.value = current_health

func apply_damage(amount: float) -> void:
	current_health = maxf(0.0, current_health - amount)
	health_bar.value = current_health
	body.modulate = Color(1.0, 0.75, 0.75, 1.0)
	var tween := create_tween()
	tween.tween_property(body, "modulate", Color.WHITE, 0.15)

	if current_health <= 0.0:
		QuestManager.report_kill(entity_data.get("id", ""))
		queue_free()

func get_armor() -> float:
	return float(entity_data.get("data", {}).get("stats", {}).get("defense", 0.0))
