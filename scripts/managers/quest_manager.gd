extends Node
## Autoload: Quest state machine driven by ForgeQuest graph data.

signal quest_started(quest_id: String)
signal objective_updated(quest_id: String, node_id: String, current: int, target: int)
signal objective_completed(quest_id: String, node_id: String)
signal quest_completed(quest_id: String)

var active_quests: Dictionary = {}
var completed_quests: Array[String] = []

func start_quest(quest_id: String) -> void:
	if active_quests.has(quest_id) or completed_quests.has(quest_id):
		return

	var quest := _get_quest(quest_id)
	if quest.is_empty():
		return

	active_quests[quest_id] = {
		"current_node": quest.get("start_node_id", ""),
		"progress": {},
		"quest_data": quest
	}
	quest_started.emit(quest_id)

func reset_state() -> void:
	active_quests.clear()
	completed_quests.clear()

func report_kill(entity_id: String) -> void:
	for quest_id in active_quests.keys():
		var state: Dictionary = active_quests[quest_id]
		var quest: Dictionary = state["quest_data"]
		var current_node_id: String = state["current_node"]

		for node in quest.get("nodes", []):
			if node["node_id"] != current_node_id:
				continue
			if node.get("objective_type") not in ["kill_entity", "kill_named"]:
				continue

			var target_ref: String = node["params"].get("target_ref", "")
			if target_ref != "ea:" + entity_id and target_ref != entity_id:
				continue

			var key: String = quest_id + ":" + current_node_id
			if not state["progress"].has(key):
				state["progress"][key] = 0
			state["progress"][key] += 1
			active_quests[quest_id] = state

			var required: int = node["params"].get("count", 1)
			objective_updated.emit(quest_id, current_node_id, state["progress"][key], required)

			if state["progress"][key] >= required:
				_advance_quest(quest_id)
			return

func _advance_quest(quest_id: String) -> void:
	var state: Dictionary = active_quests[quest_id]
	var quest: Dictionary = state["quest_data"]
	var current: String = state["current_node"]

	for edge in quest.get("edges", []):
		if edge["from"] != current:
			continue

		var next_node_id: String = edge["to"]
		for node in quest.get("nodes", []):
			if node["node_id"] == next_node_id and node["type"] == "terminal_success":
				objective_completed.emit(quest_id, current)
				_complete_quest(quest_id)
				return

		state["current_node"] = next_node_id
		active_quests[quest_id] = state
		objective_completed.emit(quest_id, current)
		return

func _complete_quest(quest_id: String) -> void:
	completed_quests.append(quest_id)
	active_quests.erase(quest_id)
	quest_completed.emit(quest_id)

func get_current_objective_text(quest_id: String) -> String:
	return String(get_quest_tracker_state(quest_id).get("objective_text", ""))

func get_quest_tracker_state(quest_id: String) -> Dictionary:
	var quest := _get_quest(quest_id)
	if quest.is_empty():
		return {}

	var tracker := {
		"quest_id": quest_id,
		"title": String(quest.get("name", quest_id)),
		"reward_profile_ref": String(quest.get("reward_profile_ref", "")),
		"objective_text": "",
		"node_id": "",
		"current": 0,
		"target": 0,
		"is_active": active_quests.has(quest_id),
		"is_completed": completed_quests.has(quest_id)
	}
	if tracker["is_completed"]:
		tracker["objective_text"] = "Quest complete"
		return tracker
	if not tracker["is_active"]:
		return tracker

	var state: Dictionary = active_quests[quest_id]
	var current_node_id := String(state.get("current_node", ""))
	var node := _get_node_by_id(quest, current_node_id)
	if node.is_empty():
		return tracker

	var params: Dictionary = node.get("params", {})
	var target: int = int(params.get("count", 1))
	var progress_key: String = _get_progress_key(quest_id, current_node_id)
	var current: int = int(state.get("progress", {}).get(progress_key, 0))
	tracker["node_id"] = current_node_id
	tracker["current"] = current
	tracker["target"] = target
	tracker["objective_text"] = _format_objective_text(node, current, target)
	return tracker

func _get_quest(quest_id: String) -> Dictionary:
	var quests: Dictionary = GameData.quest_data
	if quests.has("quests"):
		for quest in quests["quests"]:
			if quest.get("id") == quest_id:
				return quest
	return {}

func _get_node_by_id(quest: Dictionary, node_id: String) -> Dictionary:
	for node in quest.get("nodes", []):
		if node.get("node_id", "") == node_id:
			return node
	return {}

func _get_progress_key(quest_id: String, node_id: String) -> String:
	return quest_id + ":" + node_id

func _format_objective_text(node: Dictionary, current: int, target: int) -> String:
	var params: Dictionary = node.get("params", {})
	var target_ref := String(params.get("target_ref", "unknown"))
	var entity := GameData.get_entity(target_ref.replace("ea:", ""))
	var entity_name := String(entity.get("name", target_ref))
	var verb := "Defeat" if node.get("objective_type", "") == "kill_named" else "Slay"
	return "%s %s (%d/%d)" % [verb, entity_name, current, target]
