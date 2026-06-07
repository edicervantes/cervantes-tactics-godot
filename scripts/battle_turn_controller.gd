extends RefCounted
class_name BattleTurnController

func unit_indices_by_team(units: Array[Node], team: String) -> Array[int]:
	var indices: Array[int] = []
	for i in units.size():
		if units[i].team == team and units[i].is_alive():
			indices.append(i)
	return indices

func remaining_actions(units: Array[Node], team := "player") -> int:
	var remaining := 0
	for unit in units:
		if unit.team == team and unit.is_alive() and not unit.acted:
			remaining += 1
	return remaining

func reset_actions(units: Array[Node], team := "player") -> void:
	for unit in units:
		if unit.team == team:
			unit.set_acted(false)

func enemy_turn_order(units: Array[Node], enemy_ai: RefCounted) -> Array[int]:
	return enemy_ai.enemy_turn_order(unit_indices_by_team(units, "enemy"))

func battle_outcome(units: Array[Node], crystal_hp: int) -> String:
	if unit_indices_by_team(units, "enemy").is_empty():
		return "win"
	if crystal_hp <= 0 or unit_indices_by_team(units, "player").is_empty():
		return "lose"
	return ""
