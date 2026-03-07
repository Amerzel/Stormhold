extends CanvasLayer

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_text: Label = $MarginContainer/VBoxContainer/HealthText
@onready var level_text: Label = $MarginContainer/VBoxContainer/LevelText
@onready var xp_bar: ProgressBar = $MarginContainer/VBoxContainer/XpBar
@onready var xp_text: Label = $MarginContainer/VBoxContainer/XpText
@onready var boss_bar_panel: PanelContainer = $BossBarMarginContainer/BossBarPanel
@onready var boss_name_text: Label = $BossBarMarginContainer/BossBarPanel/VBoxContainer/BossName
@onready var boss_health_bar: ProgressBar = $BossBarMarginContainer/BossBarPanel/VBoxContainer/BossHealthBar
@onready var boss_health_text: Label = $BossBarMarginContainer/BossBarPanel/VBoxContainer/BossHealthText
@onready var quest_panel: PanelContainer = $QuestMarginContainer/QuestPanel
@onready var quest_title_text: Label = $QuestMarginContainer/QuestPanel/VBoxContainer/QuestTitle
@onready var quest_objective_text: Label = $QuestMarginContainer/QuestPanel/VBoxContainer/QuestObjective
@onready var notification_list: VBoxContainer = $NotificationMarginContainer/NotificationPanel/NotificationList
@onready var gold_text: Label = $MarginContainer/VBoxContainer/InventoryPanel/VBoxContainer/Gold
@onready var potion_text: Label = $MarginContainer/VBoxContainer/InventoryPanel/VBoxContainer/Potions
@onready var weapon_text: Label = $MarginContainer/VBoxContainer/InventoryPanel/VBoxContainer/Weapon
@onready var armor_text: Label = $MarginContainer/VBoxContainer/InventoryPanel/VBoxContainer/Armor
@onready var pause_weapon_list: Label = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/InventoryPanel/VBoxContainer/Weapons
@onready var pause_armor_list: Label = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/InventoryPanel/VBoxContainer/Armors
@onready var cycle_weapon_button: Button = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/InventoryPanel/VBoxContainer/CycleWeaponButton
@onready var cycle_armor_button: Button = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/InventoryPanel/VBoxContainer/CycleArmorButton
@onready var ability_name_labels: Array[Label] = [
	$MarginContainer/VBoxContainer/AbilityBar/Ability1/VBoxContainer/Name,
	$MarginContainer/VBoxContainer/AbilityBar/Ability2/VBoxContainer/Name,
	$MarginContainer/VBoxContainer/AbilityBar/Ability3/VBoxContainer/Name
]
@onready var ability_key_labels: Array[Label] = [
	$MarginContainer/VBoxContainer/AbilityBar/Ability1/VBoxContainer/Key,
	$MarginContainer/VBoxContainer/AbilityBar/Ability2/VBoxContainer/Key,
	$MarginContainer/VBoxContainer/AbilityBar/Ability3/VBoxContainer/Key
]
@onready var ability_cooldown_bars: Array[ProgressBar] = [
	$MarginContainer/VBoxContainer/AbilityBar/Ability1/VBoxContainer/CooldownBar,
	$MarginContainer/VBoxContainer/AbilityBar/Ability2/VBoxContainer/CooldownBar,
	$MarginContainer/VBoxContainer/AbilityBar/Ability3/VBoxContainer/CooldownBar
]
@onready var ability_cooldown_labels: Array[Label] = [
	$MarginContainer/VBoxContainer/AbilityBar/Ability1/VBoxContainer/CooldownText,
	$MarginContainer/VBoxContainer/AbilityBar/Ability2/VBoxContainer/CooldownText,
	$MarginContainer/VBoxContainer/AbilityBar/Ability3/VBoxContainer/CooldownText
]
@onready var death_overlay: ColorRect = $DeathOverlay
@onready var restart_button: Button = $DeathOverlay/CenterContainer/PanelContainer/VBoxContainer/RestartButton
@onready var victory_overlay: ColorRect = $VictoryOverlay
@onready var victory_body: Label = $VictoryOverlay/CenterContainer/PanelContainer/VBoxContainer/Body
@onready var victory_stats: Label = $VictoryOverlay/CenterContainer/PanelContainer/VBoxContainer/Stats
@onready var play_again_button: Button = $VictoryOverlay/CenterContainer/PanelContainer/VBoxContainer/PlayAgainButton
@onready var pause_overlay: ColorRect = $PauseOverlay
@onready var resume_button: Button = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/ResumeButton
@onready var pause_restart_button: Button = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/RestartButton
@onready var quit_button: Button = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/QuitButton
@onready var pause_level_value: Label = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/StatsPanel/VBoxContainer/Level
@onready var pause_attack_value: Label = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/StatsPanel/VBoxContainer/Attack
@onready var pause_defense_value: Label = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/StatsPanel/VBoxContainer/Defense
@onready var pause_health_value: Label = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/StatsPanel/VBoxContainer/Health
@onready var pause_primary_stat_value: Label = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/StatsPanel/VBoxContainer/Primary
@onready var pause_secondary_stat_value: Label = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/StatsPanel/VBoxContainer/Secondary

var _player: Node
var _tracked_quest_id := ""
var _notification_entries: Array[Dictionary] = []
var _boss_enemy: Node
var _latest_run_stats: Dictionary = {
	"enemies_killed": 0,
	"damage_dealt": 0,
	"time_elapsed": 0.0
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	death_overlay.visible = false
	victory_overlay.visible = false
	pause_overlay.visible = false
	quest_panel.visible = false
	boss_bar_panel.visible = false
	restart_button.pressed.connect(_on_restart_button_pressed)
	play_again_button.pressed.connect(_on_play_again_button_pressed)
	resume_button.pressed.connect(_on_resume_button_pressed)
	pause_restart_button.pressed.connect(_on_restart_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	cycle_weapon_button.pressed.connect(_on_cycle_weapon_button_pressed)
	cycle_armor_button.pressed.connect(_on_cycle_armor_button_pressed)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause_game") and not victory_overlay.visible and not death_overlay.visible:
		_toggle_pause()
	if is_instance_valid(_player) and _player.has_method("get_ability_hud_state"):
		_update_ability_bar(_player.get_ability_hud_state())
	_update_boss_bar()
	_update_notifications(_delta)

func bind_player(player: Node) -> void:
	_player = player
	if player.has_signal("health_changed"):
		set_health(player.current_health, player.max_health)
		player.inventory_changed.connect(_update_inventory_panel)
	if player.has_signal("notification_requested"):
		player.notification_requested.connect(push_notification)
	if player.has_signal("progression_changed"):
		player.progression_changed.connect(_update_progression_panel)
	if player.has_signal("run_stats_changed"):
		player.run_stats_changed.connect(_update_run_stats)
	if player.has_method("get_ability_hud_state"):
		_update_ability_bar(player.get_ability_hud_state())
	if player.has_method("get_inventory_snapshot"):
		_update_inventory_panel(player.get_inventory_snapshot())
	if player.has_method("get_stat_snapshot"):
		_update_progression_panel(player.get_stat_snapshot())
	if player.has_method("get_run_snapshot"):
		_update_run_stats(player.get_run_snapshot())

func bind_quest(quest_id: String) -> void:
	_tracked_quest_id = quest_id
	_connect_quest_manager_signals()
	_refresh_quest_tracker()
	var tracker := QuestManager.get_quest_tracker_state(quest_id)
	if not tracker.is_empty():
		push_notification("Quest: %s" % String(tracker.get("title", quest_id)), "quest")

func set_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_text.text = "HP %d / %d" % [roundi(current), roundi(maximum)]

func show_death_screen() -> void:
	if victory_overlay.visible:
		return
	get_tree().paused = true
	pause_overlay.visible = false
	death_overlay.visible = true

func _on_restart_button_pressed() -> void:
	_restart_run()

func show_victory_screen(quest_id: String = _tracked_quest_id) -> void:
	var tracker := QuestManager.get_quest_tracker_state(quest_id)
	var quest_title := String(tracker.get("title", "the quest"))
	var reward_profile_ref := String(tracker.get("reward_profile_ref", "")).trim_prefix("rp:").replace("-", " ")
	if reward_profile_ref.is_empty():
		victory_body.text = "You secured the clearing and completed %s." % quest_title
	else:
		victory_body.text = "You secured the clearing and completed %s.\nReward profile: %s" % [quest_title, reward_profile_ref.capitalize()]
	if is_instance_valid(_player) and _player.has_method("get_run_snapshot"):
		_latest_run_stats = _player.get_run_snapshot().duplicate(true)
	_update_victory_stats()
	push_notification("Quest complete: %s" % quest_title, "quest")
	get_tree().paused = true
	death_overlay.visible = false
	pause_overlay.visible = false
	victory_overlay.visible = true

func _on_play_again_button_pressed() -> void:
	_restart_run()

func _restart_run() -> void:
	get_tree().paused = false
	QuestManager.reset_state()
	get_tree().reload_current_scene()

func _update_ability_bar(states: Array) -> void:
	for index in ability_name_labels.size():
		if index >= states.size():
			ability_name_labels[index].text = "-"
			ability_key_labels[index].text = "-"
			ability_cooldown_bars[index].visible = false
			ability_cooldown_labels[index].text = ""
			continue

		var state: Dictionary = states[index]
		var cooldown: float = float(state.get("cooldown", 0.0))
		var cooldown_remaining: float = float(state.get("cooldown_remaining", 0.0))
		ability_name_labels[index].text = state.get("name", "-")
		ability_key_labels[index].text = state.get("key", "-")
		ability_cooldown_bars[index].visible = cooldown > 0.0
		ability_cooldown_bars[index].max_value = maxf(cooldown, 0.01)
		ability_cooldown_bars[index].value = cooldown_remaining
		ability_cooldown_labels[index].text = "" if cooldown_remaining <= 0.0 else "%.1fs" % cooldown_remaining

func _update_inventory_panel(snapshot: Dictionary) -> void:
	gold_text.text = "Gold: %d" % int(snapshot.get("gold", 0))
	potion_text.text = "Potions: %d / %d" % [int(snapshot.get("health_potions", 0)), int(snapshot.get("potion_capacity", 0))]
	weapon_text.text = "Weapon: %s" % String(snapshot.get("weapon_name", "None"))
	armor_text.text = "Armor: %s" % String(snapshot.get("armor_name", "None"))
	pause_weapon_list.text = "Weapons: %s" % ", ".join(snapshot.get("owned_weapons", ["None"]))
	pause_armor_list.text = "Armor: %s" % ", ".join(snapshot.get("owned_armors", ["None"]))

func _update_progression_panel(snapshot: Dictionary) -> void:
	level_text.text = "Level %d" % int(snapshot.get("level", 1))
	xp_bar.max_value = maxf(float(snapshot.get("xp_to_next", 1)), 1.0)
	xp_bar.value = float(snapshot.get("xp", 0))
	xp_text.text = "XP %d / %d" % [int(snapshot.get("xp", 0)), int(snapshot.get("xp_to_next", 1))]
	pause_level_value.text = "Level: %d" % int(snapshot.get("level", 1))
	pause_attack_value.text = "Attack: %d" % int(snapshot.get("attack", 0))
	pause_defense_value.text = "Defense: %d" % int(snapshot.get("defense", 0))
	pause_health_value.text = "Max HP: %d" % int(snapshot.get("max_health", 0))
	pause_primary_stat_value.text = "%s: %d" % [String(snapshot.get("primary_stat_name", "Primary")), int(snapshot.get("primary_stat_value", 0))]
	pause_secondary_stat_value.text = "%s: %d" % [String(snapshot.get("secondary_stat_name", "Secondary")), int(snapshot.get("secondary_stat_value", 0))]

func _update_run_stats(snapshot: Dictionary) -> void:
	_latest_run_stats = snapshot.duplicate(true)
	if victory_overlay.visible:
		_update_victory_stats()

func push_notification(text: String, kind: String = "info") -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.modulate = _get_notification_color(kind)
	notification_list.add_child(label)
	_notification_entries.append({
		"label": label,
		"time_remaining": 3.2
	})
	while _notification_entries.size() > 5:
		var oldest: Dictionary = _notification_entries.pop_front()
		var oldest_label: Label = oldest.get("label")
		if is_instance_valid(oldest_label):
			oldest_label.queue_free()

func _update_notifications(delta: float) -> void:
	var live_entries: Array[Dictionary] = []
	for entry in _notification_entries:
		var label: Label = entry.get("label")
		if not is_instance_valid(label):
			continue
		var time_remaining := maxf(0.0, float(entry.get("time_remaining", 0.0)) - delta)
		if time_remaining <= 0.0:
			label.queue_free()
			continue
		label.modulate.a = clampf(time_remaining, 0.0, 1.0)
		entry["time_remaining"] = time_remaining
		live_entries.append(entry)
	_notification_entries = live_entries

func _get_notification_color(kind: String) -> Color:
	match kind:
		"equip":
			return Color(0.70, 0.95, 0.72, 1.0)
		"loot":
			return Color(0.98, 0.90, 0.55, 1.0)
		"consumable":
			return Color(0.88, 0.65, 0.98, 1.0)
		"quest":
			return Color(0.68, 0.88, 1.0, 1.0)
	return Color.WHITE

func _connect_quest_manager_signals() -> void:
	if not QuestManager.quest_started.is_connected(_on_quest_started):
		QuestManager.quest_started.connect(_on_quest_started)
	if not QuestManager.objective_updated.is_connected(_on_objective_updated):
		QuestManager.objective_updated.connect(_on_objective_updated)
	if not QuestManager.objective_completed.is_connected(_on_objective_completed):
		QuestManager.objective_completed.connect(_on_objective_completed)
	if not QuestManager.quest_completed.is_connected(_on_quest_completed):
		QuestManager.quest_completed.connect(_on_quest_completed)

func _refresh_quest_tracker() -> void:
	if _tracked_quest_id.is_empty():
		quest_panel.visible = false
		return

	var tracker := QuestManager.get_quest_tracker_state(_tracked_quest_id)
	if tracker.is_empty():
		quest_panel.visible = false
		return

	quest_panel.visible = true
	quest_title_text.text = String(tracker.get("title", "Quest"))
	quest_objective_text.text = String(tracker.get("objective_text", "Awaiting objective"))

func _on_quest_started(quest_id: String) -> void:
	if quest_id == _tracked_quest_id:
		_refresh_quest_tracker()

func _on_objective_updated(quest_id: String, _node_id: String, _current: int, _target: int) -> void:
	if quest_id == _tracked_quest_id:
		_refresh_quest_tracker()

func _on_objective_completed(quest_id: String, _node_id: String) -> void:
	if quest_id == _tracked_quest_id:
		push_notification("Objective complete", "quest")
		_refresh_quest_tracker()

func _on_quest_completed(quest_id: String) -> void:
	if quest_id != _tracked_quest_id:
		return

	_refresh_quest_tracker()
	show_victory_screen(quest_id)

func _toggle_pause() -> void:
	if death_overlay.visible or victory_overlay.visible:
		return
	var next_paused := not get_tree().paused
	get_tree().paused = next_paused
	pause_overlay.visible = next_paused

func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	pause_overlay.visible = false

func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()

func _on_cycle_weapon_button_pressed() -> void:
	if is_instance_valid(_player) and _player.has_method("cycle_equipped_weapon"):
		_player.cycle_equipped_weapon()

func _on_cycle_armor_button_pressed() -> void:
	if is_instance_valid(_player) and _player.has_method("cycle_equipped_armor"):
		_player.cycle_equipped_armor()

func _update_boss_bar() -> void:
	if not is_instance_valid(_boss_enemy):
		_boss_enemy = _find_boss_enemy()
	if not is_instance_valid(_boss_enemy):
		boss_bar_panel.visible = false
		_boss_enemy = null
		return
	if not _boss_enemy.has_method("get_health_snapshot"):
		boss_bar_panel.visible = false
		return

	var snapshot: Dictionary = _boss_enemy.get_health_snapshot()
	var enemy_name := "Boss"
	if _boss_enemy.has_method("get_enemy_id"):
		var enemy: Dictionary = GameData.get_entity(String(_boss_enemy.get_enemy_id()))
		enemy_name = String(enemy.get("name", "Boss"))
	boss_bar_panel.visible = float(snapshot.get("current", 0.0)) > 0.0
	boss_name_text.text = enemy_name
	boss_health_bar.max_value = maxf(float(snapshot.get("max", 1.0)), 1.0)
	boss_health_bar.value = float(snapshot.get("current", 0.0))
	boss_health_text.text = "%d / %d" % [roundi(float(snapshot.get("current", 0.0))), roundi(float(snapshot.get("max", 1.0)))]

func _update_victory_stats() -> void:
	victory_stats.text = "Enemies defeated: %d\nDamage dealt: %d\nTime elapsed: %s" % [
		int(_latest_run_stats.get("enemies_killed", 0)),
		int(_latest_run_stats.get("damage_dealt", 0)),
		_format_time(float(_latest_run_stats.get("time_elapsed", 0.0)))
	]

func _find_boss_enemy() -> Node:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("get_enemy_id") and String(enemy.get_enemy_id()) == "enm-goblin-shaman":
			return enemy
	return null

func _format_time(total_seconds: float) -> String:
	var seconds: int = maxi(0, roundi(total_seconds))
	var minutes := int(seconds / 60)
	var remainder := int(seconds % 60)
	return "%02d:%02d" % [minutes, remainder]
