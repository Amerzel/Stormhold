extends Area2D

const RuntimeTextureLoader := preload("res://scripts/resources/runtime_texture_loader.gd")

@onready var visual: Polygon2D = $Visual
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var direction := Vector2.RIGHT
var speed := 160.0
var lifetime := 3.0
var damage := 0.0
var status_effect_id := ""
var sprite_config: Dictionary = {}
var tint := Color(0.95, 0.45, 0.18, 1.0)
var hit_radius := 8.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visual()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime = maxf(0.0, lifetime - delta)
	if lifetime <= 0.0:
		queue_free()

func configure(config: Dictionary) -> void:
	direction = Vector2(config.get("direction", Vector2.RIGHT)).normalized()
	speed = float(config.get("speed", speed))
	lifetime = float(config.get("lifetime", lifetime))
	damage = float(config.get("damage", damage))
	status_effect_id = String(config.get("status_effect_id", status_effect_id))
	tint = config.get("tint", tint)
	hit_radius = float(config.get("hit_radius", hit_radius))
	sprite_config = config.get("sprite_config", {})
	if is_node_ready():
		_apply_visual()

func _apply_visual() -> void:
	var circle_shape := collision_shape.shape as CircleShape2D
	if circle_shape != null:
		circle_shape.radius = hit_radius

	if sprite_config.is_empty():
		visual.visible = true
		visual.color = tint
		sprite.visible = false
		return

	var frames := RuntimeTextureLoader.load_sprite_frames(
		String(sprite_config.get("path", "")),
		int(sprite_config.get("columns", 1)),
		int(sprite_config.get("rows", 1)),
		sprite_config.get("frame_indices", []),
		float(sprite_config.get("fps", 10.0)),
		false
	)
	if frames == null:
		visual.visible = true
		visual.color = tint
		sprite.visible = false
		return

	sprite.sprite_frames = frames
	sprite.animation = "default"
	sprite.play("default")
	sprite.position = sprite_config.get("position", Vector2.ZERO)
	sprite.scale = sprite_config.get("scale", Vector2.ONE)
	sprite.modulate = tint
	sprite.visible = true
	visual.visible = false

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("apply_damage"):
		body.apply_damage(damage)
	if not status_effect_id.is_empty() and body.has_method("apply_status_effect"):
		body.apply_status_effect(status_effect_id)
	queue_free()
