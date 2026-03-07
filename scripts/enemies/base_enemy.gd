extends CharacterBody2D

const StatusEffectSystem := preload("res://scripts/systems/status_effect_system.gd")
const RuntimeTextureLoader := preload("res://scripts/resources/runtime_texture_loader.gd")
const ENEMY_SCENE := preload("res://scenes/enemies/base_enemy.tscn")
const LOOT_DROP_SCENE := preload("res://scenes/pickups/loot_drop.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/projectiles/enemy_projectile.tscn")
const GROUND_TELEGRAPH_SCENE := preload("res://scenes/projectiles/ground_telegraph.tscn")

@export var entity_data: Dictionary = {}

@onready var health_bar: ProgressBar = $HealthBar
@onready var body: Polygon2D = $PlaceholderBody
@onready var sprite: AnimatedSprite2D = $Sprite2D

var current_health := 0.0
var max_health := 0.0

var _player: Node
var _status_effects
var _behavior_tree: Dictionary = {}

var _spawn_center := Vector2.ZERO
var _encounter_radius_pixels := 0.0
var _patrol_target := Vector2.ZERO
var _has_patrol_target := false
var _state_name := "idle"
var _current_sprite_key := ""

var _attack_cooldown_remaining := 0.0
var _retreat_timer_remaining := 0.0
var _troll_windup_remaining := 0.0
var _troll_recovery_remaining := 0.0
var _troll_attack_ready := false
var _troll_swing_count := 0
var _boss_summon_cooldown_remaining := 0.0
var _boss_aoe_cooldown_remaining := 0.0
var _boss_dash_cooldown_remaining := 0.0
var _active_summons: Array[Node] = []

var _is_dead := false
var _spider_hidden := false
var _spider_ambush_ready := false
var _low_hp_threshold := 0.2
var _flee_speed_multiplier := 1.5
var _spider_ambush_damage_multiplier := 2.0
var _hit_flash_remaining := 0.0

func _ready() -> void:
	name = entity_data.get("id", "enemy")
	add_to_group("enemies")
	_status_effects = StatusEffectSystem.new(self)
	_behavior_tree = GameData.get_behavior_tree(String(entity_data.get("id", "")))

	var stats: Dictionary = entity_data.get("data", {}).get("stats", {})
	max_health = float(stats.get("hp", 1.0))
	current_health = max_health
	health_bar.max_value = max_health
	health_bar.value = current_health

	if _spawn_center == Vector2.ZERO:
		_spawn_center = global_position
	if _encounter_radius_pixels <= 0.0:
		_encounter_radius_pixels = 4.0 * float(GameData.get_tile_size())

	_load_behavior_parameters()
	_spider_hidden = bool(entity_data.get("data", {}).get("hidden_until_aggro", false))
	_apply_state("hidden" if _spider_hidden else "idle")
	_refresh_visuals()
	_update_health_bar_layout()

func initialize_spawn(encounter_center: Vector2, encounter_radius_tiles: float) -> void:
	_spawn_center = encounter_center
	_encounter_radius_pixels = encounter_radius_tiles * float(GameData.get_tile_size())

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_update_timers(delta)
	_status_effects.update(delta)
	_prune_summons()

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(_player):
		return
	if _player.has_method("is_dead") and bool(_player.call("is_dead")):
		velocity = Vector2.ZERO
		_apply_state("idle")
		move_and_slide()
		return

	var enemy_data: Dictionary = entity_data.get("data", {})
	var tile_size: float = float(GameData.get_tile_size())
	var attack_range_pixels: float = float(enemy_data.get("attack_range", 0.0)) * tile_size
	var aggro_range_pixels: float = float(enemy_data.get("aggro_range", 0.0)) * tile_size
	var move_speed_pixels: float = float(enemy_data.get("movement_speed", 0.0)) * tile_size * _status_effects.get_multiplier("movement_speed")
	var to_player: Vector2 = _player.global_position - global_position
	var distance_to_player: float = to_player.length()
	var detected: bool = _is_player_detected(distance_to_player, aggro_range_pixels)

	if _should_flee():
		_handle_flee(to_player, move_speed_pixels)
	elif _status_effects.prevents_movement():
		velocity = Vector2.ZERO
		_apply_state("idle")
	elif _retreat_timer_remaining > 0.0:
		velocity = -to_player.normalized() * move_speed_pixels * _flee_speed_multiplier
		_apply_state("run")
	elif String(entity_data.get("id", "")) == "enm-goblin-grunt":
		_update_grunt(detected, distance_to_player, attack_range_pixels, move_speed_pixels, to_player)
	elif String(entity_data.get("id", "")) == "enm-goblin-bomber":
		_update_bomber(detected, distance_to_player, attack_range_pixels, move_speed_pixels, to_player)
	elif String(entity_data.get("id", "")) == "enm-forest-spider":
		_update_spider(detected, distance_to_player, aggro_range_pixels, attack_range_pixels, move_speed_pixels, to_player)
	elif String(entity_data.get("id", "")) == "enm-troll-brute":
		_update_troll(distance_to_player, attack_range_pixels, move_speed_pixels, to_player)
	elif String(entity_data.get("id", "")) == "enm-goblin-shaman":
		_update_shaman(distance_to_player, attack_range_pixels, move_speed_pixels, to_player)
	else:
		_update_default_enemy(detected, distance_to_player, attack_range_pixels, move_speed_pixels, to_player)

	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0

	move_and_slide()
	_refresh_visuals()

func apply_damage(amount: float) -> void:
	if _is_dead:
		return

	current_health = maxf(0.0, current_health - amount)
	_hit_flash_remaining = 0.12
	health_bar.value = current_health

	if current_health <= 0.0:
		_is_dead = true
		velocity = Vector2.ZERO
		if is_instance_valid(_player) and _player.has_method("award_enemy_xp"):
			_player.award_enemy_xp(String(entity_data.get("id", "")))
		if is_instance_valid(_player) and _player.has_method("register_enemy_kill"):
			_player.register_enemy_kill()
		_spawn_loot()
		QuestManager.report_kill(String(entity_data.get("id", "")))
		queue_free()

func apply_dot_damage(amount: float) -> void:
	apply_damage(amount)

func apply_status_effect(effect_id: String) -> void:
	_status_effects.apply_effect(effect_id)
	_refresh_visuals()

func get_armor() -> float:
	return float(entity_data.get("data", {}).get("stats", {}).get("defense", 0.0))

func get_enemy_id() -> String:
	return String(entity_data.get("id", ""))

func get_health_snapshot() -> Dictionary:
	return {
		"current": current_health,
		"max": max_health
	}

func _update_grunt(detected: bool, distance_to_player: float, attack_range_pixels: float, move_speed_pixels: float, to_player: Vector2) -> void:
	if detected:
		_alert_pack()
		if distance_to_player <= attack_range_pixels:
			velocity = Vector2.ZERO
			_apply_state("attack")
			_attack_player(1.0, "")
			return

		velocity = to_player.normalized() * move_speed_pixels
		_apply_state("run")
		return

	_patrol(move_speed_pixels * 0.6)

func _update_bomber(detected: bool, distance_to_player: float, attack_range_pixels: float, move_speed_pixels: float, to_player: Vector2) -> void:
	var flee_range_pixels := float(entity_data.get("data", {}).get("flee_range", 0.0)) * float(GameData.get_tile_size())
	if detected:
		if distance_to_player < flee_range_pixels:
			velocity = -to_player.normalized() * move_speed_pixels * _flee_speed_multiplier
			_apply_state("run")
			return
		if distance_to_player > attack_range_pixels:
			velocity = to_player.normalized() * move_speed_pixels
			_apply_state("run")
			return

		velocity = Vector2.ZERO
		_apply_state("attack")
		_throw_bomb_projectile(to_player)
		return

	_patrol(move_speed_pixels * 0.55)

func _update_spider(detected: bool, distance_to_player: float, aggro_range_pixels: float, attack_range_pixels: float, move_speed_pixels: float, to_player: Vector2) -> void:
	health_bar.visible = not _spider_hidden
	if _spider_hidden:
		if detected:
			_spider_hidden = false
			_spider_ambush_ready = true
		else:
			velocity = Vector2.ZERO
			_apply_state("hidden")
			return

	if _retreat_timer_remaining > 0.0:
		velocity = -to_player.normalized() * move_speed_pixels * _flee_speed_multiplier
		_apply_state("run")
		if distance_to_player > aggro_range_pixels * 1.4:
			_spider_hidden = true
			_spider_ambush_ready = true
			velocity = Vector2.ZERO
			_apply_state("hidden")
		return

	if _spider_ambush_ready and distance_to_player <= attack_range_pixels * 1.2:
		velocity = Vector2.ZERO
		_apply_state("attack")
		_attack_player(_spider_ambush_damage_multiplier, "")
		_spider_ambush_ready = false
		_retreat_timer_remaining = float(entity_data.get("data", {}).get("attack_cooldown", 0.8))
		return

	if detected:
		if distance_to_player <= attack_range_pixels:
			velocity = Vector2.ZERO
			_apply_state("attack")
			_attack_player(1.0, "")
		else:
			velocity = to_player.normalized() * move_speed_pixels
			_apply_state("run")
		return

	_spider_hidden = true
	velocity = Vector2.ZERO
	_apply_state("hidden")

func _update_troll(distance_to_player: float, attack_range_pixels: float, move_speed_pixels: float, to_player: Vector2) -> void:
	var enemy_data: Dictionary = entity_data.get("data", {})
	if _troll_recovery_remaining > 0.0:
		velocity = Vector2.ZERO
		_apply_state("recovery")
		return

	if _troll_attack_ready:
		_troll_attack_ready = false
		velocity = Vector2.ZERO
		_apply_state("attack")
		_attack_player(1.0, "")
		_troll_swing_count += 1
		if _troll_swing_count >= int(enemy_data.get("recovery_after_swings", 3)):
			_troll_swing_count = 0
			_troll_recovery_remaining = float(enemy_data.get("recovery_duration", 2.0))
		return

	if _troll_windup_remaining > 0.0:
		velocity = Vector2.ZERO
		_apply_state("windup")
		return

	if distance_to_player <= attack_range_pixels and _attack_cooldown_remaining <= 0.0:
		_troll_windup_remaining = float(enemy_data.get("windup_duration", 1.0))
		velocity = Vector2.ZERO
		_apply_state("windup")
		return

	if distance_to_player <= attack_range_pixels:
		velocity = Vector2.ZERO
		_apply_state("idle")
		return

	velocity = to_player.normalized() * move_speed_pixels
	_apply_state("run")

func _update_shaman(distance_to_player: float, attack_range_pixels: float, move_speed_pixels: float, to_player: Vector2) -> void:
	var enemy_data: Dictionary = entity_data.get("data", {})
	var hp_ratio: float = current_health / maxf(max_health, 1.0)
	var phase_list: Array = enemy_data.get("phases", [])
	var phase_one: Dictionary = phase_list[0] if phase_list.size() > 0 else {}
	var phase_two: Dictionary = phase_list[1] if phase_list.size() > 1 else {}

	if hp_ratio <= float(phase_two.get("hp_threshold", 0.4)):
		if _boss_summon_cooldown_remaining <= 0.0 and _active_summons.size() < 4:
			_summon_grunts(int(phase_one.get("summon_count", 2)), String(phase_one.get("summon_ref", "enm-goblin-grunt")))
			_boss_summon_cooldown_remaining = float(phase_one.get("summon_interval", 15.0))
			velocity = Vector2.ZERO
			_apply_state("summon")
			return

		var fire_bomb: Dictionary = GameData.get_entity("con-fire-bomb")
		var explosion_radius_pixels: float = float(fire_bomb.get("data", {}).get("aoe_radius", 2.0)) * float(GameData.get_tile_size())
		if _boss_aoe_cooldown_remaining <= 0.0 and distance_to_player <= explosion_radius_pixels:
			_boss_aoe_cooldown_remaining = float(phase_two.get("explosion_interval", 8.0))
			velocity = Vector2.ZERO
			_apply_state("aoe")
			_spawn_ground_telegraph(explosion_radius_pixels, 0.8, 1.0, "sfx-burning")
			return

		if distance_to_player > attack_range_pixels:
			velocity = to_player.normalized() * move_speed_pixels * 0.8
			_apply_state("run")
			return

		velocity = Vector2.ZERO
		_apply_state("attack")
		_cast_shaman_projectile(to_player, 1.0, "sfx-burning")
		return

	if distance_to_player > attack_range_pixels * 1.25 and _boss_dash_cooldown_remaining <= 0.0:
		_boss_dash_cooldown_remaining = 3.0
		velocity = to_player.normalized() * move_speed_pixels * 2.2
		_apply_state("run")
		return

	if distance_to_player > attack_range_pixels:
		velocity = to_player.normalized() * move_speed_pixels
		_apply_state("run")
		return

	velocity = Vector2.ZERO
	_apply_state("attack")
	_cast_shaman_projectile(to_player, 1.0, "")

func _update_default_enemy(detected: bool, distance_to_player: float, attack_range_pixels: float, move_speed_pixels: float, to_player: Vector2) -> void:
	if detected:
		if distance_to_player <= attack_range_pixels:
			velocity = Vector2.ZERO
			_apply_state("attack")
			_attack_player(1.0, "")
		else:
			velocity = to_player.normalized() * move_speed_pixels
			_apply_state("run")
	else:
		_patrol(move_speed_pixels * 0.5)

func _patrol(move_speed_pixels: float) -> void:
	if not _has_patrol_target or global_position.distance_to(_patrol_target) < 8.0:
		var radius := maxf(_encounter_radius_pixels, 32.0)
		_patrol_target = _spawn_center + Vector2(
			randf_range(-radius, radius),
			randf_range(-radius, radius)
		)
		_has_patrol_target = true

	var to_target := _patrol_target - global_position
	if to_target.length() > 4.0:
		velocity = to_target.normalized() * move_speed_pixels
		_apply_state("run")
	else:
		velocity = Vector2.ZERO
		_apply_state("idle")

func _handle_flee(to_player: Vector2, move_speed_pixels: float) -> void:
	velocity = -to_player.normalized() * move_speed_pixels * _flee_speed_multiplier
	_apply_state("run")
	if String(entity_data.get("id", "")) == "enm-forest-spider" and to_player.length() > float(entity_data.get("data", {}).get("aggro_range", 3.0)) * float(GameData.get_tile_size()) * 1.4:
		_spider_hidden = true
		_spider_ambush_ready = true
		velocity = Vector2.ZERO
		_apply_state("hidden")

func _attack_player(damage_multiplier: float, status_effect_id: String) -> void:
	if _attack_cooldown_remaining > 0.0 or _status_effects.prevents_attack():
		return

	var damage: float = _calculate_player_damage(damage_multiplier)
	if _player.has_method("apply_damage"):
		_player.call("apply_damage", damage)
	if not status_effect_id.is_empty() and _player.has_method("apply_status_effect"):
		_player.call("apply_status_effect", status_effect_id)
	_attack_cooldown_remaining = float(entity_data.get("data", {}).get("attack_cooldown", 1.0))

func _should_flee() -> bool:
	if String(entity_data.get("id", "")) in ["enm-goblin-shaman", "enm-troll-brute"]:
		return false
	return current_health <= max_health * _low_hp_threshold

func _is_player_detected(distance_to_player: float, aggro_range_pixels: float) -> bool:
	if distance_to_player <= aggro_range_pixels:
		return true
	var encounter := get_parent()
	if encounter != null and encounter.has_meta("alerted") and bool(encounter.get_meta("alerted")):
		return String(entity_data.get("id", "")) in ["enm-goblin-grunt", "enm-goblin-bomber"]
	return false

func _alert_pack() -> void:
	var encounter := get_parent()
	if encounter != null:
		encounter.set_meta("alerted", true)

func _summon_grunts(count: int, summon_ref: String) -> void:
	var summon_entity := GameData.get_entity(summon_ref)
	if summon_entity.is_empty():
		return

	for index in count:
		var summon := ENEMY_SCENE.instantiate()
		summon.entity_data = summon_entity
		var angle := TAU * (float(index) / maxf(float(count), 1.0))
		var offset := Vector2.RIGHT.rotated(angle) * float(GameData.get_tile_size()) * 1.5
		summon.global_position = global_position + offset
		get_parent().add_child(summon)
		if summon.has_method("initialize_spawn"):
			summon.initialize_spawn(_spawn_center, _encounter_radius_pixels / float(GameData.get_tile_size()))
		_active_summons.append(summon)

func _prune_summons() -> void:
	var live_summons: Array[Node] = []
	for summon in _active_summons:
		if is_instance_valid(summon):
			live_summons.append(summon)
	_active_summons = live_summons

func _update_timers(delta: float) -> void:
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_retreat_timer_remaining = maxf(0.0, _retreat_timer_remaining - delta)
	_troll_recovery_remaining = maxf(0.0, _troll_recovery_remaining - delta)
	_boss_summon_cooldown_remaining = maxf(0.0, _boss_summon_cooldown_remaining - delta)
	_boss_aoe_cooldown_remaining = maxf(0.0, _boss_aoe_cooldown_remaining - delta)
	_boss_dash_cooldown_remaining = maxf(0.0, _boss_dash_cooldown_remaining - delta)
	_hit_flash_remaining = maxf(0.0, _hit_flash_remaining - delta)

	if _troll_windup_remaining > 0.0:
		_troll_windup_remaining = maxf(0.0, _troll_windup_remaining - delta)
		if _troll_windup_remaining <= 0.0:
			_troll_attack_ready = true

func _load_behavior_parameters() -> void:
	var flee_condition := _find_behavior_node("condition", "hp_below")
	if not flee_condition.is_empty():
		_low_hp_threshold = float(flee_condition.get("conditionParams", {}).get("threshold", _low_hp_threshold))

	var flee_action := _find_behavior_node("action", "flee")
	if flee_action.is_empty():
		flee_action = _find_behavior_node("action", "retreat_to_hiding")
	if not flee_action.is_empty():
		_flee_speed_multiplier = float(flee_action.get("actionParams", {}).get("speed", _flee_speed_multiplier))

	var ambush_action := _find_behavior_node("action", "ambush_attack")
	if not ambush_action.is_empty():
		_spider_ambush_damage_multiplier = float(ambush_action.get("actionParams", {}).get("damageMultiplier", _spider_ambush_damage_multiplier))

func _find_behavior_node(node_type: String, key: String) -> Dictionary:
	if _behavior_tree.is_empty():
		return {}
	return _search_behavior_node(_behavior_tree.get("root", {}), node_type, key)

func _search_behavior_node(node: Dictionary, node_type: String, key: String) -> Dictionary:
	if node.get("type", "") == node_type:
		if node_type == "condition" and node.get("condition", "") == key:
			return node
		if node_type == "action" and node.get("action", "") == key:
			return node
		if node_type == "decorator" and node.get("decorator", "") == key:
			return node

	for child in node.get("children", []):
		var result: Dictionary = _search_behavior_node(child, node_type, key)
		if not result.is_empty():
			return result
	return {}

func _apply_state(state_name: String) -> void:
	if _state_name == state_name:
		return
	_state_name = state_name
	_update_sprite_for_state()

func _refresh_visuals() -> void:
	_update_sprite_for_state()

	var tint := Color.WHITE
	if _hit_flash_remaining > 0.0:
		tint = Color(1.0, 0.82, 0.82, 1.0)
	elif _status_effects != null and _status_effects.has_effect("sfx-stunned"):
		tint = Color(0.88, 0.84, 0.22, 1.0)
	elif _status_effects != null and _status_effects.has_effect("sfx-burning"):
		tint = Color(0.95, 0.50, 0.26, 1.0)

	if _spider_hidden:
		tint.a = 0.22

	body.color = tint
	sprite.modulate = tint
	health_bar.visible = not _spider_hidden
	_update_health_bar_layout()

func _update_sprite_for_state() -> void:
	var config := _get_sprite_config()
	if config.is_empty():
		sprite.visible = false
		body.visible = true
		_update_health_bar_layout()
		return

	var sprite_key := "%s:%s" % [config.get("path", ""), ",".join(_to_string_array(config.get("frame_indices", [])))]
	if sprite_key != _current_sprite_key:
		var frames := RuntimeTextureLoader.load_sprite_frames(
			config.get("path", ""),
			int(config.get("columns", 1)),
			int(config.get("rows", 1)),
			config.get("frame_indices", []),
			float(config.get("fps", 8.0)),
			false
		)
		if frames == null:
			sprite.visible = false
			body.visible = true
			return
		sprite.sprite_frames = frames
		sprite.animation = "default"
		sprite.play("default")
		_current_sprite_key = sprite_key
	elif not sprite.is_playing():
		sprite.play("default")

	sprite.scale = config.get("scale", Vector2.ONE)
	sprite.position = config.get("position", Vector2.ZERO)
	sprite.visible = true
	body.visible = false
	_update_health_bar_layout()

func _update_health_bar_layout() -> void:
	var bar_width := 36.0
	var top_offset := -30.0
	var texture := _get_current_frame_texture()
	if sprite.visible and texture != null:
		bar_width = clampf(float(texture.get_width()) * absf(sprite.scale.x) * 0.7, 28.0, 72.0)
		top_offset = sprite.position.y - (float(texture.get_height()) * absf(sprite.scale.y) * 0.5) - 10.0
	health_bar.offset_left = -bar_width * 0.5
	health_bar.offset_right = bar_width * 0.5
	health_bar.offset_top = top_offset
	health_bar.offset_bottom = top_offset + maxf(health_bar.custom_minimum_size.y, 6.0)

func _get_sprite_config() -> Dictionary:
	match String(entity_data.get("id", "")):
		"enm-goblin-grunt":
			return _build_sheet_config("res://art/_tiny_swords/Tiny Swords/Tiny Swords (Update 010)/Factions/Goblins/Troops/Torch/Blue/Torch_Blue.png", 7, 5, _get_sheet_row_for_state({"idle": 0, "run": 1, "attack": 2, "hidden": 0}), 8.0, Vector2.ONE, Vector2(0, -8))
		"enm-goblin-bomber":
			return _build_sheet_config("res://art/_tiny_swords/Tiny Swords/Tiny Swords (Update 010)/Factions/Goblins/Troops/TNT/Blue/TNT_Blue.png", 7, 3, _get_sheet_row_for_state({"idle": 0, "run": 1, "attack": 2}), 8.0, Vector2.ONE, Vector2(0, -8))
		"enm-forest-spider":
			if _state_name == "attack":
				return _build_sheet_config("res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Spider/Spider_Attack.png", 8, 1, 0, 11.0, Vector2(0.9, 0.9), Vector2(0, -6))
			if _state_name == "run":
				return _build_sheet_config("res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Spider/Spider_Run.png", 5, 1, 0, 10.0, Vector2(0.9, 0.9), Vector2(0, -6))
			return _build_sheet_config("res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Spider/Spider_Idle.png", 8, 1, 0, 8.0, Vector2(0.9, 0.9), Vector2(0, -6))
		"enm-troll-brute":
			if _state_name == "attack":
				return _build_sheet_config("res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Troll/Troll_Attack.png", 6, 1, 0, 8.0, Vector2(0.45, 0.45), Vector2(0, -18))
			if _state_name == "windup":
				return _build_sheet_config("res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Troll/Troll_Windup.png", 5, 1, 0, 7.0, Vector2(0.45, 0.45), Vector2(0, -18))
			if _state_name == "recovery":
				return _build_sheet_config("res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Troll/Troll_Recovery.png", 10, 1, 0, 10.0, Vector2(0.45, 0.45), Vector2(0, -18))
			if _state_name == "run":
				return _build_sheet_config("res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Troll/Troll_Walk.png", 10, 1, 0, 9.0, Vector2(0.45, 0.45), Vector2(0, -18))
			return _build_sheet_config("res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Troll/Troll_Idle.png", 12, 1, 0, 8.0, Vector2(0.45, 0.45), Vector2(0, -18))
		"enm-goblin-shaman":
			if _state_name == "attack":
				return _build_sheet_config("res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Shaman/Shaman_Attack.png", 10, 1, 0, 11.0, Vector2(0.9, 0.9), Vector2(0, -10))
			if _state_name == "aoe":
				return _build_sheet_config("res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Shaman/Shaman_Explosion.png", 9, 1, 0, 12.0, Vector2(0.9, 0.9), Vector2(0, -10))
			if _state_name == "run" or _state_name == "summon":
				return _build_sheet_config("res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Shaman/Shaman_Run.png", 4, 1, 0, 8.0, Vector2(0.9, 0.9), Vector2(0, -10))
			return _build_sheet_config("res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Shaman/Shaman_Idle.png", 8, 1, 0, 8.0, Vector2(0.9, 0.9), Vector2(0, -10))
	return {}

func _build_sheet_config(path: String, columns: int, rows: int, row: int, fps: float, scale: Vector2, position: Vector2) -> Dictionary:
	return {
		"path": path,
		"columns": columns,
		"rows": rows,
		"frame_indices": _row_to_indices(columns, row),
		"fps": fps,
		"scale": scale,
		"position": position
	}

func _get_sheet_row_for_state(row_map: Dictionary) -> int:
	if row_map.has(_state_name):
		return int(row_map[_state_name])
	return int(row_map.get("idle", 0))

func _row_to_indices(columns: int, row: int) -> Array:
	var indices: Array = []
	var start := row * columns
	for column in columns:
		indices.append(start + column)
	return indices

func _get_current_frame_texture() -> Texture2D:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation("default"):
		return null
	return sprite.sprite_frames.get_frame_texture("default", sprite.frame)

func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result

func _calculate_player_damage(damage_multiplier: float) -> float:
	var enemy_data: Dictionary = entity_data.get("data", {})
	var player_armor := 0.0
	if _player.has_method("get_defense"):
		player_armor = float(_player.call("get_defense"))
	var attack_power := float(enemy_data.get("stats", {}).get("attack", 0.0))
	return CombatManager.calculate_physical_damage(attack_power * damage_multiplier, 1.0, player_armor)

func _throw_bomb_projectile(to_player: Vector2) -> void:
	if _attack_cooldown_remaining > 0.0 or _status_effects.prevents_attack():
		return
	var projectile := ENEMY_PROJECTILE_SCENE.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(0, -6)
	projectile.configure({
		"direction": to_player.normalized(),
		"speed": float(GameData.get_tile_size()) * 4.4,
		"lifetime": 2.0,
		"damage": _calculate_player_damage(1.0),
		"status_effect_id": "sfx-burning",
		"tint": Color(0.96, 0.50, 0.16, 1.0),
		"hit_radius": 9.0
	})
	_attack_cooldown_remaining = float(entity_data.get("data", {}).get("attack_cooldown", 1.0))

func _cast_shaman_projectile(to_player: Vector2, damage_multiplier: float, status_effect_id: String) -> void:
	if _attack_cooldown_remaining > 0.0 or _status_effects.prevents_attack():
		return
	var projectile := ENEMY_PROJECTILE_SCENE.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(0, -10)
	projectile.configure({
		"direction": to_player.normalized(),
		"speed": float(GameData.get_tile_size()) * 5.0,
		"lifetime": 2.4,
		"damage": _calculate_player_damage(damage_multiplier),
		"status_effect_id": status_effect_id,
		"tint": Color(0.62, 0.90, 1.0, 1.0),
		"hit_radius": 8.0,
		"sprite_config": {
			"path": "res://art/_tiny_swords/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Shaman/Shaman_Projectile.png",
			"columns": 7,
			"rows": 1,
			"frame_indices": _row_to_indices(7, 0),
			"fps": 12.0,
			"scale": Vector2(0.8, 0.8),
			"position": Vector2.ZERO
		}
	})
	_attack_cooldown_remaining = float(entity_data.get("data", {}).get("attack_cooldown", 1.0))

func _spawn_ground_telegraph(radius_pixels: float, warning_time: float, damage_multiplier: float, status_effect_id: String) -> void:
	var telegraph := GROUND_TELEGRAPH_SCENE.instantiate()
	get_parent().add_child(telegraph)
	telegraph.global_position = _player.global_position
	telegraph.configure({
		"radius_pixels": radius_pixels,
		"warning_time": warning_time,
		"damage": _calculate_player_damage(damage_multiplier),
		"status_effect_id": status_effect_id
	})

func _spawn_loot() -> void:
	var loot_table_id := String(entity_data.get("data", {}).get("loot_table_ref", ""))
	if loot_table_id.is_empty():
		return

	var loot_table := GameData.get_loot_table(loot_table_id)
	var drops := CombatManager.roll_loot(loot_table)
	var parent := get_parent()
	if parent == null:
		return

	for index in drops.size():
		var drop_data: Dictionary = drops[index]
		var pickup := LOOT_DROP_SCENE.instantiate()
		pickup.configure(String(drop_data.get("item_ref", "")), int(drop_data.get("count", 1)))
		parent.add_child(pickup)
		var spread := Vector2.RIGHT.rotated(TAU * (float(index) / maxf(float(drops.size()), 1.0))) * 18.0
		pickup.global_position = global_position + spread
