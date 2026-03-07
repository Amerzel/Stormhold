extends CharacterBody2D

const AbilitySystem := preload("res://scripts/combat/ability_system.gd")
const Inventory := preload("res://scripts/player/inventory.gd")
const StatusEffectSystem := preload("res://scripts/systems/status_effect_system.gd")
const RuntimeTextureLoader := preload("res://scripts/resources/runtime_texture_loader.gd")
const PLAYER_SPRITE_PATH := "res://art/_tiny_swords/Tiny Swords/Tiny Swords (Update 010)/Factions/Knights/Troops/Warrior/Blue/Warrior_Blue.png"
const PLAYER_SPRITE_COLUMNS := 6
const PLAYER_SPRITE_ROWS := 8

signal health_changed(current: float, maximum: float)
signal died
signal inventory_changed(snapshot: Dictionary)
signal notification_requested(text: String, kind: String)
signal progression_changed(snapshot: Dictionary)
signal run_stats_changed(snapshot: Dictionary)

@onready var visual: Polygon2D = $Visual
@onready var sprite: AnimatedSprite2D = $Sprite2D
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
var _base_stats: Dictionary = {}
var _player_level := 1
var _current_xp := 0
var _xp_to_next_level := 1
var _run_time_seconds := 0.0
var _enemies_killed := 0
var _damage_dealt_total := 0.0
var _current_animation_state := ""
var _visual_action_state := ""
var _visual_action_remaining := 0.0
var _hurt_flash_remaining := 0.0
var _camera_shake_remaining := 0.0
var _camera_shake_strength := 0.0

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
	progression_changed.emit(get_stat_snapshot())
	run_stats_changed.emit(get_run_snapshot())

func _physics_process(delta: float) -> void:
	_status_effects.update(delta)
	_ability_system.update(delta)
	_update_feedback_timers(delta)
	if not _is_dead:
		_run_time_seconds += delta

	if _is_dead:
		velocity = Vector2.ZERO
		_refresh_visual_state()
		move_and_slide()
		return
		
	if _status_effects.prevents_movement():
		_dodge_time_remaining = 0.0

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _status_effects.prevents_movement():
		input_direction = Vector2.ZERO

	var move_speed_tiles: float = float(GameData.player_class.get("data", {}).get("movement_speed", 0.0)) * _status_effects.get_multiplier("movement_speed")
	var move_speed_pixels: float = move_speed_tiles * float(GameData.get_tile_size())

	if _dodge_time_remaining > 0.0:
		_dodge_time_remaining = maxf(0.0, _dodge_time_remaining - delta)
		velocity = _dodge_velocity
		_refresh_visual_state()
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
	_refresh_visual_state()

func apply_damage(amount: float) -> void:
	if _is_dead or _is_invincible():
		return

	current_health = maxf(0.0, current_health - amount)
	_trigger_hit_feedback(5.0, 0.18)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		_is_dead = true
		died.emit()

func apply_dot_damage(amount: float) -> void:
	if _is_dead:
		return

	current_health = maxf(0.0, current_health - amount)
	_trigger_hit_feedback(4.0, 0.14)
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

func cycle_equipped_weapon() -> void:
	if not _inventory.cycle_weapon():
		return
	_refresh_equipment_stats(max_health)
	inventory_changed.emit(_inventory.get_snapshot())
	notification_requested.emit("Equipped %s" % String(GameData.get_entity(_inventory.equipped_weapon_id).get("name", _inventory.equipped_weapon_id)), "equip")

func cycle_equipped_armor() -> void:
	if not _inventory.cycle_armor():
		return
	_refresh_equipment_stats(max_health)
	inventory_changed.emit(_inventory.get_snapshot())
	notification_requested.emit("Equipped %s" % String(GameData.get_entity(_inventory.equipped_armor_id).get("name", _inventory.equipped_armor_id)), "equip")

func get_stat_snapshot() -> Dictionary:
	var class_data: Dictionary = GameData.player_class.get("data", {})
	var primary_stat_name := String(class_data.get("primary_stat", "strength"))
	var secondary_stat_name := String(class_data.get("secondary_stat", "vitality"))
	return {
		"level": _player_level,
		"xp": _current_xp,
		"xp_to_next": _xp_to_next_level,
		"primary_stat_name": primary_stat_name.capitalize(),
		"primary_stat_value": int(_base_stats.get(primary_stat_name, 0)),
		"secondary_stat_name": secondary_stat_name.capitalize(),
		"secondary_stat_value": int(_base_stats.get(secondary_stat_name, 0)),
		"attack": roundi(float(_equipped_weapon.get("attack", 0.0))),
		"defense": roundi(float(_equipped_armor.get("defense", 0.0))),
		"max_health": roundi(max_health)
	}

func get_run_snapshot() -> Dictionary:
	return {
		"enemies_killed": _enemies_killed,
		"damage_dealt": roundi(_damage_dealt_total),
		"time_elapsed": _run_time_seconds
	}

func award_enemy_xp(entity_id: String) -> void:
	var xp_amount := GameData.get_enemy_xp_reward(entity_id)
	if xp_amount <= 0:
		return
	_award_xp(xp_amount, "Defeated %s" % String(GameData.get_entity(entity_id).get("name", entity_id)))

func register_enemy_kill() -> void:
	_enemies_killed += 1
	run_stats_changed.emit(get_run_snapshot())

func collect_loot(item_ref: String, count: int) -> void:
	var previous_max_health := max_health
	var equipment_changed: bool = _inventory.add_item(item_ref, count)
	if equipment_changed:
		_refresh_equipment_stats(previous_max_health)
	inventory_changed.emit(_inventory.get_snapshot())
	_emit_loot_notification(item_ref, count, equipment_changed)

func _configure_camera_limits() -> void:
	var zone_dimensions: Vector2i = GameData.get_zone_dimensions()
	var tile_size: int = GameData.get_tile_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = zone_dimensions.x * tile_size
	camera.limit_bottom = zone_dimensions.y * tile_size

func _initialize_loadout() -> void:
	var class_data: Dictionary = GameData.player_class.get("data", {})
	_base_stats = class_data.get("starting_stats", {}).duplicate(true)
	_player_level = 1
	_current_xp = 0
	_xp_to_next_level = GameData.get_xp_required_for_level(_player_level)
	_inventory.configure_from_class(class_data)
	_refresh_equipment_stats(0.0)
	current_health = max_health
	_run_time_seconds = 0.0
	_enemies_killed = 0
	_damage_dealt_total = 0.0

func _try_attack() -> void:
	if _attack_cooldown_remaining > 0.0 or _status_effects.prevents_attack():
		return

	var attack_speed := float(_equipped_weapon.get("speed", 1.0))
	if attack_speed <= 0.0:
		attack_speed = 1.0
	_attack_cooldown_remaining = 1.0 / attack_speed
	_play_action_animation("attack", maxf(0.16, _attack_cooldown_remaining * 0.45))

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
	_play_action_animation("dodge", dodge_duration)

	if dodge_direction.x != 0.0:
		visual.scale.x = -1.0 if dodge_direction.x < 0.0 else 1.0
		sprite.flip_h = dodge_direction.x < 0.0

func _is_invincible() -> bool:
	var dodge_data: Dictionary = GameData.player_class.get("data", {}).get("dodge", {})
	return _dodge_time_remaining > 0.0 and bool(dodge_data.get("invincible", false))

func perform_ability(_ability_id: String, ability_data: Dictionary) -> bool:
	match ability_data.get("type", ""):
		"active_melee":
			_play_action_animation("attack", 0.24)
			return _perform_shield_bash(ability_data)
		"active_aoe":
			_play_action_animation("whirlwind", 0.42)
			return _perform_whirlwind(ability_data)
		"self_buff":
			_play_action_animation("battle_cry", 0.35)
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
	var target_health := 0.0
	if enemy.has_method("get_armor"):
		target_armor = float(enemy.get_armor())
	if enemy.has_method("get_health_snapshot"):
		var health_snapshot: Dictionary = enemy.get_health_snapshot()
		target_health = float(health_snapshot.get("current", 0.0))

	var base_attack: float = float(_equipped_weapon.get("attack", 0.0)) * _status_effects.get_multiplier("damage")
	var damage: float
	if is_equal_approx(damage_multiplier, 1.0):
		damage = CombatManager.calculate_physical_damage(base_attack, 1.0, target_armor)
	else:
		damage = CombatManager.calculate_ability_damage(base_attack, 1.0, damage_multiplier, target_armor)
	enemy.apply_damage(damage)
	if target_health <= 0.0:
		target_health = damage
	_damage_dealt_total += minf(damage, target_health)
	run_stats_changed.emit(get_run_snapshot())

	if not applied_status_id.is_empty() and enemy.has_method("apply_status_effect"):
		enemy.apply_status_effect(applied_status_id)

func _refresh_visual_state() -> void:
	var tint := Color.WHITE
	if _is_dead:
		tint = Color(0.28, 0.28, 0.28, 1.0)
	elif _hurt_flash_remaining > 0.0:
		tint = Color(1.0, 0.72, 0.72, 1.0)
	elif _status_effects != null and _status_effects.has_effect("sfx-battle-fury"):
		tint = Color(0.72, 0.92, 1.0, 1.0)
	elif _status_effects != null and _status_effects.has_effect("sfx-stunned"):
		tint = Color(0.56, 0.56, 0.56, 1.0)
	else:
		tint = Color.WHITE

	_apply_player_animation(_get_visual_animation_state())
	sprite.modulate = tint
	visual.color = Color(0.24, 0.46, 0.86, 1.0) if sprite.visible == false else Color(0.24, 0.46, 0.86, 0.0)

func _load_player_sprite() -> void:
	var frames := RuntimeTextureLoader.load_sprite_frames(PLAYER_SPRITE_PATH, PLAYER_SPRITE_COLUMNS, PLAYER_SPRITE_ROWS, _row_to_indices(0), 6.0, false)
	if frames == null:
		sprite.visible = false
		visual.visible = true
		return

	sprite.sprite_frames = frames
	sprite.animation = "default"
	sprite.play("default")
	sprite.scale = Vector2.ONE
	sprite.visible = true
	visual.visible = false

func _refresh_equipment_stats(previous_max_health: float) -> void:
	var class_data: Dictionary = GameData.player_class.get("data", {})
	_equipped_weapon = _inventory.get_weapon_data()
	_equipped_armor = _inventory.get_armor_data()
	var vitality_stat_name := String(class_data.get("secondary_stat", "vitality"))
	var vitality := int(_base_stats.get(vitality_stat_name, 0))
	var base_hp := GameData.calculate_character_max_hp(vitality) * float(class_data.get("hp_modifier", 1.0))
	if base_hp <= 0.0:
		base_hp = float(class_data.get("starting_hp", 0.0))
	max_health = base_hp + float(_equipped_armor.get("hp_bonus", 0.0))
	if current_health > 0.0:
		current_health = minf(max_health, current_health + maxf(0.0, max_health - previous_max_health))
		health_changed.emit(current_health, max_health)
	progression_changed.emit(get_stat_snapshot())

func _use_health_potion() -> void:
	if current_health >= max_health:
		return
	if not _inventory.consume_health_potion():
		return

	var potion := GameData.get_entity("con-health-potion")
	var potency := float(potion.get("data", {}).get("potency", 0.0))
	current_health = minf(max_health, current_health + potency)
	_play_action_animation("battle_cry", 0.18)
	health_changed.emit(current_health, max_health)
	inventory_changed.emit(_inventory.get_snapshot())
	notification_requested.emit("Used %s (+%d HP)" % [String(potion.get("name", "Health Potion")), roundi(potency)], "consumable")

func _update_feedback_timers(delta: float) -> void:
	_visual_action_remaining = maxf(0.0, _visual_action_remaining - delta)
	_hurt_flash_remaining = maxf(0.0, _hurt_flash_remaining - delta)
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_dodge_cooldown_remaining = maxf(0.0, _dodge_cooldown_remaining - delta)
	if _camera_shake_remaining > 0.0:
		_camera_shake_remaining = maxf(0.0, _camera_shake_remaining - delta)
		camera.offset = Vector2(
			randf_range(-_camera_shake_strength, _camera_shake_strength),
			randf_range(-_camera_shake_strength, _camera_shake_strength)
		)
	else:
		if camera.offset.length_squared() < 0.01:
			camera.offset = Vector2.ZERO
		camera.offset = camera.offset.lerp(Vector2.ZERO, minf(delta * 16.0, 1.0))

func _trigger_hit_feedback(strength: float, duration: float) -> void:
	_hurt_flash_remaining = maxf(_hurt_flash_remaining, duration)
	_camera_shake_strength = maxf(_camera_shake_strength, strength)
	_camera_shake_remaining = maxf(_camera_shake_remaining, duration)
	_play_action_animation("hurt", duration)

func _play_action_animation(state_name: String, duration: float) -> void:
	_visual_action_state = state_name
	_visual_action_remaining = maxf(_visual_action_remaining, duration)

func _get_visual_animation_state() -> String:
	if _is_dead:
		return "dead"
	if _hurt_flash_remaining > 0.0:
		return "hurt"
	if _visual_action_remaining > 0.0 and not _visual_action_state.is_empty():
		return _visual_action_state
	if _dodge_time_remaining > 0.0:
		return "dodge"
	if velocity.length() > 1.0:
		return "run"
	return "idle"

func _apply_player_animation(state_name: String) -> void:
	if state_name == _current_animation_state and sprite.visible:
		if not sprite.is_playing():
			sprite.play("default")
		return

	var config := _get_player_animation_config(state_name)
	var frames := RuntimeTextureLoader.load_sprite_frames(
		PLAYER_SPRITE_PATH,
		PLAYER_SPRITE_COLUMNS,
		PLAYER_SPRITE_ROWS,
		config.get("frame_indices", []),
		float(config.get("fps", 6.0)),
		false
	)
	if frames == null:
		sprite.visible = false
		visual.visible = true
		return

	sprite.sprite_frames = frames
	sprite.animation = "default"
	sprite.play("default")
	sprite.scale = config.get("scale", Vector2.ONE)
	sprite.position = config.get("position", Vector2(0, -16))
	sprite.visible = true
	visual.visible = false
	_current_animation_state = state_name

func _get_player_animation_config(state_name: String) -> Dictionary:
	match state_name:
		"run":
			return {"frame_indices": _row_to_indices(1), "fps": 9.0, "position": Vector2(0, -16), "scale": Vector2.ONE}
		"dodge":
			return {"frame_indices": _row_to_indices(2), "fps": 12.0, "position": Vector2(0, -16), "scale": Vector2.ONE}
		"attack":
			return {"frame_indices": _row_to_indices(3), "fps": 12.0, "position": Vector2(0, -16), "scale": Vector2.ONE}
		"whirlwind":
			return {"frame_indices": _row_to_indices(4), "fps": 12.0, "position": Vector2(0, -16), "scale": Vector2.ONE}
		"battle_cry":
			return {"frame_indices": _row_to_indices(5), "fps": 10.0, "position": Vector2(0, -16), "scale": Vector2.ONE}
		"hurt":
			return {"frame_indices": _row_to_indices(6), "fps": 10.0, "position": Vector2(0, -16), "scale": Vector2.ONE}
		"dead":
			return {"frame_indices": _row_to_indices(7), "fps": 6.0, "position": Vector2(0, -16), "scale": Vector2.ONE}
	return {"frame_indices": _row_to_indices(0), "fps": 6.0, "position": Vector2(0, -16), "scale": Vector2.ONE}

func _row_to_indices(row: int) -> Array:
	var frame_indices: Array = []
	var start := row * PLAYER_SPRITE_COLUMNS
	for column in PLAYER_SPRITE_COLUMNS:
		frame_indices.append(start + column)
	return frame_indices

func _emit_loot_notification(item_ref: String, count: int, equipment_changed: bool) -> void:
	if item_ref.begins_with("currency:"):
		notification_requested.emit("Picked up %d gold" % count, "loot")
		return

	var item: Dictionary = GameData.get_entity(item_ref)
	var item_name := String(item.get("name", item_ref))
	if equipment_changed:
		notification_requested.emit("Equipped %s" % item_name, "equip")
		return
	if count > 1:
		notification_requested.emit("Picked up %s x%d" % [item_name, count], "loot")
	else:
		notification_requested.emit("Picked up %s" % item_name, "loot")

func _award_xp(amount: int, source_text: String) -> void:
	if amount <= 0:
		return
	if _player_level >= GameData.get_level_cap():
		return

	_current_xp += amount
	notification_requested.emit("+%d XP - %s" % [amount, source_text], "quest")
	while _player_level < GameData.get_level_cap() and _current_xp >= _xp_to_next_level:
		_current_xp -= _xp_to_next_level
		_apply_level_up()
	progression_changed.emit(get_stat_snapshot())

func _apply_level_up() -> void:
	var previous_max_health := max_health
	var class_data: Dictionary = GameData.player_class.get("data", {})
	var secondary_stat_name := String(class_data.get("secondary_stat", "vitality"))
	_base_stats[secondary_stat_name] = int(_base_stats.get(secondary_stat_name, 0)) + 1
	_player_level += 1
	_xp_to_next_level = GameData.get_xp_required_for_level(_player_level)
	_refresh_equipment_stats(previous_max_health)
	current_health = max_health
	health_changed.emit(current_health, max_health)
	notification_requested.emit("Level Up! Reached level %d" % _player_level, "quest")
