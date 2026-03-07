extends Node2D

var radius_pixels := 48.0
var warning_time := 0.8
var damage := 0.0
var status_effect_id := ""
var fill_color := Color(0.95, 0.35, 0.20, 0.25)
var outline_color := Color(1.0, 0.65, 0.25, 0.9)

func _process(delta: float) -> void:
	warning_time = maxf(0.0, warning_time - delta)
	queue_redraw()
	if warning_time <= 0.0:
		_detonate()

func configure(config: Dictionary) -> void:
	radius_pixels = float(config.get("radius_pixels", radius_pixels))
	warning_time = float(config.get("warning_time", warning_time))
	damage = float(config.get("damage", damage))
	status_effect_id = String(config.get("status_effect_id", status_effect_id))
	fill_color = config.get("fill_color", fill_color)
	outline_color = config.get("outline_color", outline_color)
	queue_redraw()

func _draw() -> void:
	var alpha := 0.35 + (1.0 - minf(warning_time, 1.0)) * 0.35
	draw_circle(Vector2.ZERO, radius_pixels, Color(fill_color.r, fill_color.g, fill_color.b, alpha))
	draw_arc(Vector2.ZERO, radius_pixels, 0.0, TAU, 32, outline_color, 3.0)

func _detonate() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.global_position.distance_to(global_position) <= radius_pixels:
		if player.has_method("apply_damage"):
			player.apply_damage(damage)
		if not status_effect_id.is_empty() and player.has_method("apply_status_effect"):
			player.apply_status_effect(status_effect_id)
	queue_free()
