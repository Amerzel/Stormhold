extends CharacterBody2D

signal health_changed(current: float, maximum: float)

@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D

var current_health := 0.0
var max_health := 0.0

var _equipped_weapon: Dictionary = {}
var _equipped_armor: Dictionary = {}
var _attack_cooldown_remaining := 0.0
var _facing_direction := Vector2.RIGHT

func _ready() -> void:
	_initialize_loadout()
	position = GameData.get_spawn_world_position()
	_configure_camera_limits()
	health_changed.emit(current_health, max_health)

func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_speed_tiles := float(GameData.player_class.get("data", {}).get("movement_speed", 0.0))
	var move_speed_pixels := move_speed_tiles * float(GameData.get_tile_size())
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)

	if input_direction.is_zero_approx():
		velocity = Vector2.ZERO
	else:
		velocity = input_direction.normalized() * move_speed_pixels
		_facing_direction = input_direction.normalized()
		if input_direction.x != 0.0:
			sprite.flip_h = input_direction.x < 0.0

	if Input.is_action_just_pressed("attack"):
		_try_attack()

	move_and_slide()

func apply_damage(amount: float) -> void:
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)

func _configure_camera_limits() -> void:
	var zone_dimensions := GameData.get_zone_dimensions()
	var tile_size := GameData.get_tile_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = zone_dimensions.x * tile_size
	camera.limit_bottom = zone_dimensions.y * tile_size

func _initialize_loadout() -> void:
	var class_data: Dictionary = GameData.player_class.get("data", {})
	var starting_gear: Array = class_data.get("starting_gear", [])

	for item_id in starting_gear:
		var item: Dictionary = GameData.get_entity(item_id)
		match item.get("category", ""):
			"weapon":
				_equipped_weapon = item.get("data", {})
			"armor":
				_equipped_armor = item.get("data", {})

	max_health = float(class_data.get("starting_hp", 0.0)) + float(_equipped_armor.get("hp_bonus", 0.0))
	current_health = max_health

func _try_attack() -> void:
	if _attack_cooldown_remaining > 0.0:
		return

	var attack_speed := float(_equipped_weapon.get("speed", 1.0))
	if attack_speed <= 0.0:
		attack_speed = 1.0
	_attack_cooldown_remaining = 1.0 / attack_speed

	var attack_direction := get_global_mouse_position() - global_position
	if attack_direction.is_zero_approx():
		attack_direction = _facing_direction
	attack_direction = attack_direction.normalized()

	var attack_range_tiles := float(GameData.player_class.get("data", {}).get("attack_range", 1.0))
	var attack_range_pixels := attack_range_tiles * float(GameData.get_tile_size())
	var base_attack := float(_equipped_weapon.get("attack", 0.0))

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.has_method("apply_damage"):
			continue

		var to_enemy: Vector2 = enemy.global_position - global_position
		if to_enemy.length() > attack_range_pixels:
			continue
		if to_enemy.length() > 0.0 and attack_direction.dot(to_enemy.normalized()) < 0.1:
			continue

		var target_armor := 0.0
		if enemy.has_method("get_armor"):
			target_armor = float(enemy.get_armor())

		var damage := CombatManager.calculate_physical_damage(base_attack, 1.0, target_armor)
		enemy.apply_damage(damage)
