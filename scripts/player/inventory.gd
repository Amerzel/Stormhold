extends RefCounted

var equipped_weapon_id := ""
var equipped_armor_id := ""
var gold := 0
var health_potions := 0
var extra_consumables: Dictionary = {}

func configure_from_class(class_data: Dictionary) -> void:
	for item_id in class_data.get("starting_gear", []):
		var item: Dictionary = GameData.get_entity(String(item_id))
		match String(item.get("category", "")):
			"weapon":
				equipped_weapon_id = String(item.get("id", ""))
			"armor":
				equipped_armor_id = String(item.get("id", ""))

func add_item(item_ref: String, count: int) -> bool:
	if item_ref.begins_with("currency:"):
		gold += count
		return false

	var item: Dictionary = GameData.get_entity(item_ref)
	var category := String(item.get("category", ""))
	match category:
		"consumable":
			if item_ref == "con-health-potion":
				health_potions += count
			else:
				extra_consumables[item_ref] = int(extra_consumables.get(item_ref, 0)) + count
			return false
		"weapon":
			if _should_equip_weapon(item_ref):
				equipped_weapon_id = item_ref
				return true
		"armor":
			if _should_equip_armor(item_ref):
				equipped_armor_id = item_ref
				return true
	return false

func consume_health_potion() -> bool:
	if health_potions <= 0:
		return false
	health_potions -= 1
	return true

func get_weapon_data() -> Dictionary:
	return GameData.get_weapon_data(equipped_weapon_id)

func get_armor_data() -> Dictionary:
	var armor: Dictionary = GameData.get_entity(equipped_armor_id)
	return armor.get("data", {}) if not armor.is_empty() else {}

func get_snapshot() -> Dictionary:
	var weapon: Dictionary = GameData.get_entity(equipped_weapon_id)
	var armor: Dictionary = GameData.get_entity(equipped_armor_id)
	return {
		"gold": gold,
		"health_potions": health_potions,
		"weapon_name": weapon.get("name", "None"),
		"armor_name": armor.get("name", "None")
	}

func _should_equip_weapon(item_ref: String) -> bool:
	var current_attack := float(get_weapon_data().get("attack", 0.0))
	var candidate_attack := float(GameData.get_weapon_data(item_ref).get("attack", 0.0))
	return candidate_attack > current_attack

func _should_equip_armor(item_ref: String) -> bool:
	var current_armor: Dictionary = get_armor_data()
	var candidate_entity: Dictionary = GameData.get_entity(item_ref)
	var candidate_armor: Dictionary = candidate_entity.get("data", {})
	var current_score := float(current_armor.get("defense", 0.0)) + float(current_armor.get("hp_bonus", 0.0)) * 0.1
	var candidate_score := float(candidate_armor.get("defense", 0.0)) + float(candidate_armor.get("hp_bonus", 0.0)) * 0.1
	return candidate_score > current_score
