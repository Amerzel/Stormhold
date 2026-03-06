extends Node
## Autoload: Quest state machine driven by ForgeQuest graph data.

signal quest_started(quest_id: String)
signal objective_updated(quest_id: String, node_id: String, current: int, target: int)
signal objective_completed(quest_id: String, node_id: String)
signal quest_completed(quest_id: String)

var active_quests: Dictionary = {}  # quest_id -> { current_node, progress }
var completed_quests: Array[String] = []

func start_quest(quest_id: String) -> void:
var quest := _get_quest(quest_id)
if quest.is_empty():
return
active_quests[quest_id] = {
"current_node": quest.get("start_node_id", ""),
"progress": {},
"quest_data": quest
}
quest_started.emit(quest_id)

func report_kill(entity_id: String) -> void:
for quest_id in active_quests:
var state: Dictionary = active_quests[quest_id]
var quest: Dictionary = state["quest_data"]
var current_node_id: String = state["current_node"]

for node in quest.get("nodes", []):
if node["node_id"] != current_node_id:
continue
if node.get("objective_type") not in ["kill_entity", "kill_named"]:
continue
var target_ref: String = node["params"].get("target_ref", "")
if target_ref == "ea:" + entity_id or target_ref == entity_id:
var key := quest_id + ":" + current_node_id
if not state["progress"].has(key):
state["progress"][key] = 0
state["progress"][key] += 1

var required: int = node["params"].get("count", 1)
objective_updated.emit(quest_id, current_node_id, state["progress"][key], required)

if state["progress"][key] >= required:
_advance_quest(quest_id)

func _advance_quest(quest_id: String) -> void:
var state: Dictionary = active_quests[quest_id]
var quest: Dictionary = state["quest_data"]
var current := state["current_node"]
objective_completed.emit(quest_id, current)

# Find next node via edges
for edge in quest.get("edges", []):
if edge["from"] == current:
var next_node_id: String = edge["to"]
# Check if terminal
for node in quest.get("nodes", []):
if node["node_id"] == next_node_id and node["type"] == "terminal_success":
_complete_quest(quest_id)
return
state["current_node"] = next_node_id
return

func _complete_quest(quest_id: String) -> void:
completed_quests.append(quest_id)
active_quests.erase(quest_id)
quest_completed.emit(quest_id)

func get_current_objective_text(quest_id: String) -> String:
if not active_quests.has(quest_id):
return ""
var state: Dictionary = active_quests[quest_id]
var quest: Dictionary = state["quest_data"]
for node in quest.get("nodes", []):
if node["node_id"] == state["current_node"]:
var target: String = node.get("params", {}).get("target_ref", "unknown")
var count: int = node.get("params", {}).get("count", 1)
var key := quest_id + ":" + state["current_node"]
var progress: int = state["progress"].get(key, 0)
var entity := GameData.get_entity(target.replace("ea:", ""))
var name: String = entity.get("name", target)
if node.get("objective_type") == "kill_named":
return "Defeat %s" % name
return "Slay %s (%d/%d)" % [name, progress, count]
return ""

func _get_quest(quest_id: String) -> Dictionary:
var quests: Dictionary = GameData.quest_data
if quests.has("quests"):
for q in quests["quests"]:
if q.get("id") == quest_id:
return q
return {}
