extends CanvasLayer

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_text: Label = $MarginContainer/VBoxContainer/HealthText

func set_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_text.text = "HP %d / %d" % [roundi(current), roundi(maximum)]
