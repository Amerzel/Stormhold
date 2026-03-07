extends CharacterBody2D

const AbilitySystem := preload("res://scripts/combat/ability_system.gd")
const Inventory := preload("res://scripts/player/inventory.gd")
const StatusEffectSystem := preload("res://scripts/systems/status_effect_system.gd")
const RuntimeTextureLoader := preload("res://scripts/resources/runtime_texture_loader.gd")
const PLAYER_SPRITE_PATH := "res://art/_tiny_swords/Tiny Swords/Tiny Swords (Update 010)/Factions/Knights/Troops/Warrior/Blue/Warrior_Blue.png"

signal health_changed(current: float, maximum: float)
signal died
signal inventory_changed(snapshot: Dictionary)

@onready var visual: Polygon2D = $Visual
@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D

var current_health := 0.0
var max_health := 0.0

var _equipped_weapon: Dictionary = {}
var _equipped_armor: Dictionary = {}
var _attack_cooldown_remaining := 0.0
var _facing_direction := Vector2.RIGHT
var _dodge_time_remaining := 0.0
var _dodge_cooldown_remaining := 0.0
var _dodge_velocity := Vector2.ZERO
var _is_dead := false
var _status_effects
var _ability_system
var _inventory

func _ready() -> void:
	add_to_group("player")
	_status_effects = StatusEffectSystem.new(self)
	_ability_system = AbilitySystem.new(self)
	_inventory = Inventory.new()
	_initialize_loadout()
	position = GameData.get_spawn_world_position()
	_configure_camera_limits()
	_ability_system.configure(GameData.player_class.get("data", {}).get("abilities", []))
	_load_player_sprite()
	_refresh_visual_state()
	health_changed.emit(current_health, max_health)
	inventory_changed.emit(_inventory.get_snapshot())

func _physics_process(delta: float) -> void:
	_status_effects.update(delta)
	_ability_system.update(delta)
	_refresh_visual_state()

	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _status_effects.prevents_movement():
		_dodge_time_remaining = 0.0

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _status_effects.prevents_movement():
		input_direction = Vector2.ZERO

	var move_speed_tiles: float = float(GameData.player_class.get("data", {}).get("movement_speed", 0.0)) * _status_effects.get_multiplier("movement_speed")
	var move_speed_pixels: float = move_speed_tiles * float(GameData.get_tile_size())
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_dodge_cooldown_remaining = maxf(0.0, _dodge_cooldown_remaining - delta)

	if _dodge_time_remaining > 0.0:
		_dodge_time_remaining = maxf(0.0, _dodge_time_remaining - delta)
		velocity = _dodge_velocity
		move_and_slide()
		return

	if input_direction.is_zero_approx():
		velocity = Vector2.ZERO
	else:
		velocity = input_direction.normalized() * move_speed_pixels
		_facing_direction = input_direction.normalized()
		if input_direction.x != 0.0:
			visual.scale.x = -1.0 if input_direction.x < 0.0 else 1.0
			sprite.flip_h = input_direction.x < 0.0

	if Input.is_action_just_pressed("dodge"):
		_try_start_dodge(input_direction)
	elif Input.is_action_just_pressed("attack"):
		_try_attack()

	for action_name in ["ability_1", "ability_2", "ability_3"]:
		if Input.is_action_just_pressed(action_name):
			_ability_system.try_activate_action(action_name)
	if Input.is_action_just_pressed("use_potion"):
		_use_health_potion()

	move_and_slide()

func apply_damage(amount: float) -> void:
	if _is_dead or _is_invincible():
		return

	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		_is_dead = true
		died.emit()

func apply_dot_damage(amount: float) -> void:
	if _is_dead:
		return

	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_is_dead = true
		died.emit()

func apply_status_effect(effect_id: String) -> void:
	_status_effects.apply_effect(effect_id)
	_refresh_visual_state()

func get_defense() -> float:
	return float(_equipped_armor.get("defense", 0.0))

func is_dead() -> bool:
	return _is_dead

func can_use_abilities() -> bool:
	return not _is_dead and not _status_effects.prevents_attack() and _dodge_time_remaining <= 0.0

func get_ability_hud_state() -> Array[Dictionary]:
	return _ability_system.get_hud_state()

func get_inventory_snapshot() -> Dictionary:
	return _inventory.get_snapshot()

func collect_loot(item_ref: String, count: int) -> void:
	var previous_max_health := max_health
	var equipment_changed: bool = _inventory.add_item(item_ref, count)
	if equipment_changed:
		_refresh_equipment_stats(previous_max_health)
	inventory_changed.emit(_inventory.get_snapshot())

func _configure_camera_limits() -> void:
	var zone_dimensions: Vector2i = GameData.get_zone_dimensions()
	var tile_size: int = GameData.get_tile_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = zone_dimensions.x * tile_size
	camera.limit_bottom = zone_dimensions.y * tile_size

func _initialize_loadout() -> void:
	var class_data: Dictionary = GameData.player_class.get("data", {})
	_inventory.configure_from_class(class_data)
	_refresh_equipment_stats(float(class_data.get("starting_hp", 0.0)))
	current_health = max_health

func _try_attack() -> void:
	if _attack_cooldown_remaining > 0.0 or _status_effects.prevents_attack():
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
	for enemy in _get_targets_in_range(attack_range_pixels, attack_direction, 0.1):
		_damage_enemy(enemy, 1.0, "")

func _try_start_dodge(input_direction: Vector2) -> void:
	if _dodge_cooldown_remaining > 0.0 or _status_effects.prevents_movement():
		return

	var dodge_data: Dictionary = GameData.player_class.get("data", {}).get("dodge", {})
	var dodge_direction := input_direction
	if dodge_direction.is_zero_approx():
		dodge_direction = _facing_direction
	if dodge_direction.is_zero_approx():
		dodge_direction = Vector2.RIGHT

	var dodge_duration := float(dodge_data.get("duration", 0.0))
	if dodge_duration <= 0.0:
		return

	dodge_direction = dodge_direction.normalized()
	var dodge_distance_pixels := float(dodge_data.get("distance", 0.0)) * float(GameData.get_tile_size())
	_dodge_velocity = dodge_direction * (dodge_distance_pixels / dodge_duration)
	_dodge_time_remaining = dodge_duration
	_dodge_cooldown_remaining = float(dodge_data.get("cooldown", 0.0))
	_facing_direction = dodge_direction

	if dodge_direction.x != 0.0:
		visual.scale.x = -1.0 if dodge_direction.x < 0.0 else 1.0
		sprite.flip_h = dodge_direction.x < 0.0

func _is_invincible() -> bool:
	var dodge_data: Dictionary = GameData.player_class.get("data", {}).get("dodge", {})
	return _dodge_time_remaining > 0.0 and bool(dodge_data.get("invincible", false))

func perform_ability(_ability_id: String, ability_data: Dictionary) -> bool:
	match ability_data.get("type", ""):
		"active_melee":
			return _perform_shield_bash(ability_data)
		"active_aoe":
			return _perform_whirlwind(ability_data)
		"self_buff":
			apply_status_effect(String(ability_data.get("applies_status", "")))
			return true
	return false

func _perform_shield_bash(ability_data: Dictionary) -> bool:
	var range_pixels := float(ability_data.get("range", 1.0)) * float(GameData.get_tile_size())
	var attack_direction := get_global_mouse_position() - global_position
	if attack_direction.is_zero_approx():
		attack_direction = _facing_direction
	attack_direction = attack_direction.normalized()

	var targets := _get_targets_in_range(range_pixels, attack_direction, 0.35)
	for enemy in targets:
		_damage_enemy(enemy, float(ability_data.get("damage_multiplier", 1.0)), String(ability_data.get("applies_status", "")))
	return true

func _perform_whirlwind(ability_data: Dictionary) -> bool:
	var radius_pixels := float(ability_data.get("aoe_radius", 1.0)) * float(GameData.get_tile_size())
	var targets := _get_targets_in_range(radius_pixels, _facing_direction, -1.0)
	for enemy in targets:
		_damage_enemy(enemy, float(ability_data.get("damage_multiplier", 1.0)), String(ability_data.get("applies_status", "")))
	return true

func _get_targets_in_range(max_range_pixels: float, direction: Vector2, min_dot: float) -> Array:
	var targets: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.has_method("apply_damage"):
			continue

		var to_enemy: Vector2 = enemy.global_position - global_position
		if to_enemy.length() > max_range_pixels:
			continue
		if min_dot > -1.0 and to_enemy.length() > 0.0 and direction.dot(to_enemy.normalized()) < min_dot:
			continue
		targets.append(enemy)
	return targets

func _damage_enemy(enemy: Node, damage_multiplier: float, applied_status_id: String) -> void:
	var target_armor := 0.0
	if enemy.has_method("get_armor"):
		target_armor = float(enemy.get_armor())

	var base_attack: float = float(_equipped_weapon.get("attack", 0.0)) * _status_effects.get_multiplier("damage")
	var damage: float
	if is_equal_approx(damage_multiplier, 1.0):
		damage = CombatManager.calculate_physical_damage(base_attack, 1.0, target_armor)
	else:
		damage = CombatManager.calculate_ability_damage(base_attack, 1.0, damage_multiplier, target_armor)
	enemy.apply_damage(damage)

	if not applied_status_id.is_empty() and enemy.has_method("apply_status_effect"):
		enemy.apply_status_effect(applied_status_id)

func _refresh_visual_state() -> void:
	var tint := Color.WHITE
	if _is_dead:
		tint = Color(0.28, 0.28, 0.28, 1.0)
	elif _status_effects != null and _status_effects.has_effect("sfx-battle-fury"):
		tint = Color(0.72, 0.92, 1.0, 1.0)
	elif _status_effects != null and _status_effects.has_effect("sfx-stunned"):
		tint = Color(0.56, 0.56, 0.56, 1.0)
	else:
		tint = Color.WHITE

	sprite.modulate = tint
	visual.color = Color(0.24, 0.46, 0.86, 1.0) if sprite.visible == false else Color(0.24, 0.46, 0.86, 0.0)

func _load_player_sprite() -> void:
	var texture := RuntimeTextureLoader.load_frame_texture(PLAYER_SPRITE_PATH, 6, 8, 0)
	if texture == null:
		sprite.visible = false
		visual.visible = true
		return

	sprite.texture = texture
	sprite.scale = Vector2.ONE
	sprite.visible = true
	visual.visible = false

func _refresh_equipment_stats(previous_max_health: float) -> void:
	var class_data: Dictionary = GameData.player_class.get("data", {})
	_equipped_weapon = _inventory.get_weapon_data()
	_equipped_armor = _inventory.get_armor_data()
	max_health = float(class_data.get("starting_hp", 0.0)) + float(_equipped_armor.get("hp_bonus", 0.0))
	if current_health > 0.0:
		current_health = minf(max_health, current_health + maxf(0.0, max_health - previous_max_health))
		health_changed.emit(current_health, max_health)

func _use_health_potion() -> void:
	if current_health >= max_health:
		return
	if not _inventory.consume_health_potion():
		return

	var potion := GameData.get_entity("con-health-potion")
	var potency := float(potion.get("data", {}).get("potency", 0.0))
	current_health = minf(max_health, current_health + potency)
	health_changed.emit(current_health, max_health)
	inventory_changed.emit(_inventory.get_snapshot())
