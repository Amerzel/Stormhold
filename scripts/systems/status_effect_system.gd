extends RefCounted

var _owner: Node
var _active_effects: Dictionary = {}

func _init(owner: Node) -> void:
	_owner = owner

func update(delta: float) -> void:
	var expired_effects: Array[String] = []
	for effect_id in _active_effects.keys():
		var state: Dictionary = _active_effects[effect_id]
		var remaining: float = float(state.get("remaining", 0.0)) - delta
		state["remaining"] = remaining

		var tick_interval: float = float(state.get("tick_interval", 0.0))
		if tick_interval > 0.0:
			var next_tick: float = float(state.get("next_tick", tick_interval)) - delta
			while next_tick <= 0.0 and remaining > 0.0:
				_apply_tick_damage(state)
				next_tick += tick_interval
			state["next_tick"] = next_tick

		_active_effects[effect_id] = state
		if remaining <= 0.0:
			expired_effects.append(effect_id)

	for effect_id in expired_effects:
		_active_effects.erase(effect_id)

func apply_effect(effect_id: String) -> void:
	if effect_id.is_empty():
		return

	var effect_data: Dictionary = GameData.get_status_effect(effect_id)
	if effect_data.is_empty():
		return

	var duration: float = float(effect_data.get("duration", 0.0))
	var state := {
		"effect_id": effect_id,
		"data": effect_data,
		"remaining": duration,
		"tick_interval": float(effect_data.get("tick_interval", 0.0)),
		"next_tick": float(effect_data.get("tick_interval", 0.0))
	}
	_active_effects[effect_id] = state

func get_multiplier(stat_name: String) -> float:
	var multiplier := 1.0
	for state in _active_effects.values():
		var effect_data: Dictionary = state.get("data", {})
		for modification in effect_data.get("stat_modifications", []):
			if modification.get("stat", "") != stat_name:
				continue
			if modification.get("modifier", "") == "multiply":
				multiplier *= float(modification.get("value", 1.0))
	return multiplier

func prevents_movement() -> bool:
	return _any_effect_flag("prevents_movement")

func prevents_attack() -> bool:
	return _any_effect_flag("prevents_attack")

func has_effect(effect_id: String) -> bool:
	return _active_effects.has(effect_id)

func get_active_effect_ids() -> Array[String]:
	var result: Array[String] = []
	for effect_id in _active_effects.keys():
		result.append(effect_id)
	return result

func _any_effect_flag(flag_name: String) -> bool:
	for state in _active_effects.values():
		var effect_data: Dictionary = state.get("data", {})
		if bool(effect_data.get(flag_name, false)):
			return true
	return false

func _apply_tick_damage(state: Dictionary) -> void:
	var effect_data: Dictionary = state.get("data", {})
	var damage_per_tick: float = float(effect_data.get("damage_per_tick", 0.0))
	if damage_per_tick <= 0.0:
		return
	if _owner != null and _owner.has_method("apply_dot_damage"):
		_owner.call("apply_dot_damage", CombatManager.calculate_dot_damage(damage_per_tick))
