extends CanvasLayer

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_text: Label = $MarginContainer/VBoxContainer/HealthText
@onready var gold_text: Label = $MarginContainer/VBoxContainer/InventoryPanel/VBoxContainer/Gold
@onready var potion_text: Label = $MarginContainer/VBoxContainer/InventoryPanel/VBoxContainer/Potions
@onready var weapon_text: Label = $MarginContainer/VBoxContainer/InventoryPanel/VBoxContainer/Weapon
@onready var armor_text: Label = $MarginContainer/VBoxContainer/InventoryPanel/VBoxContainer/Armor
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

var _player: Node

func _ready() -> void:
	death_overlay.visible = false
	restart_button.pressed.connect(_on_restart_button_pressed)

func _process(_delta: float) -> void:
	if is_instance_valid(_player) and _player.has_method("get_ability_hud_state"):
		_update_ability_bar(_player.get_ability_hud_state())

func bind_player(player: Node) -> void:
	_player = player
	if player.has_signal("health_changed"):
		set_health(player.current_health, player.max_health)
		player.inventory_changed.connect(_update_inventory_panel)
	if player.has_method("get_ability_hud_state"):
		_update_ability_bar(player.get_ability_hud_state())
	if player.has_method("get_inventory_snapshot"):
		_update_inventory_panel(player.get_inventory_snapshot())

func set_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_text.text = "HP %d / %d" % [roundi(current), roundi(maximum)]

func show_death_screen() -> void:
	death_overlay.visible = true

func _on_restart_button_pressed() -> void:
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
	potion_text.text = "Potions: %d" % int(snapshot.get("health_potions", 0))
	weapon_text.text = "Weapon: %s" % String(snapshot.get("weapon_name", "None"))
	armor_text.text = "Armor: %s" % String(snapshot.get("armor_name", "None"))
