extends Node2D

const MAIN_QUEST_ID := "quest:clear-the-clearing"

@onready var player = $Player
@onready var player_hud = $PlayerHud

func _ready() -> void:
	if not QuestManager.active_quests.has(MAIN_QUEST_ID) and not QuestManager.completed_quests.has(MAIN_QUEST_ID):
		QuestManager.start_quest(MAIN_QUEST_ID)

	player.health_changed.connect(player_hud.set_health)
	player.died.connect(player_hud.show_death_screen)
	player_hud.bind_player(player)
