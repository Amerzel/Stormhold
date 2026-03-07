extends RefCounted

const SLOT_BINDINGS := [
	{"action": "ability_1", "key": "Q"},
	{"action": "ability_2", "key": "E"},
	{"action": "ability_3", "key": "R"}
]

var _owner: Node
var _ability_ids: Array[String] = []
var _cooldowns: Dictionary = {}

func _init(owner: Node) -> void:
	_owner = owner

func configure(ability_ids: Array) -> void:
	_ability_ids.clear()
	for ability_id in ability_ids:
		_ability_ids.append(String(ability_id))

func update(delta: float) -> void:
	for ability_id in _cooldowns.keys():
		var remaining: float = maxf(0.0, float(_cooldowns[ability_id]) - delta)
		_cooldowns[ability_id] = remaining

func try_activate_action(action_name: String) -> bool:
	var slot_index := _get_slot_index(action_name)
	if slot_index < 0 or slot_index >= _ability_ids.size():
		return false
	return try_activate_ability(_ability_ids[slot_index])

func try_activate_ability(ability_id: String) -> bool:
	if ability_id.is_empty():
		return false
	if float(_cooldowns.get(ability_id, 0.0)) > 0.0:
		return false
	if _owner == null or not _owner.has_method("can_use_abilities"):
		return false
	if not bool(_owner.call("can_use_abilities")):
		return false

	var ability_data: Dictionary = GameData.get_ability_data(ability_id)
	if ability_data.is_empty():
		return false
	if not _owner.has_method("perform_ability"):
		return false

	var did_use := bool(_owner.call("perform_ability", ability_id, ability_data))
	if did_use:
		_cooldowns[ability_id] = float(ability_data.get("cooldown", 0.0))
	return did_use

func get_hud_state() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for index in SLOT_BINDINGS.size():
		var ability_id := ""
		if index < _ability_ids.size():
			ability_id = _ability_ids[index]
		var ability_entity := {}
		var ability_data := {}
		if not ability_id.is_empty():
			ability_entity = GameData.get_entity(ability_id)
			ability_data = ability_entity.get("data", {})

		states.append({
			"action": SLOT_BINDINGS[index]["action"],
			"key": SLOT_BINDINGS[index]["key"],
			"ability_id": ability_id,
			"name": ability_entity.get("name", "-"),
			"cooldown": float(ability_data.get("cooldown", 0.0)),
			"cooldown_remaining": float(_cooldowns.get(ability_id, 0.0))
		})
	return states

func _get_slot_index(action_name: String) -> int:
	for index in SLOT_BINDINGS.size():
		if SLOT_BINDINGS[index]["action"] == action_name:
			return index
	return -1
