extends RefCounted
class_name EnemyAI

const ATTACK_UNIT := "attack_unit"
const HIT_CRYSTAL := "hit_crystal"
const MOVE := "move"
const WAIT := "wait"

var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func set_seed(seed_value: int) -> void:
	rng.seed = seed_value

func enemy_turn_order(enemy_indices: Array[int]) -> Array[int]:
	var ordered := enemy_indices.duplicate()
	for i in range(ordered.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: int = ordered[i]
		ordered[i] = ordered[j]
		ordered[j] = temp
	return ordered

func choose_attack_target(candidates: Array[Dictionary]) -> int:
	if candidates.is_empty():
		return -1

	var best_index: int = -1
	var best_score: float = -99999.0
	for candidate in candidates:
		var hp: int = max(1, int(candidate.get("hp", 1)))
		var max_hp: int = max(1, int(candidate.get("max_hp", hp)))
		var hp_pressure: float = (1.0 - float(hp) / float(max_hp)) * 36.0
		var distance_pressure: float = max(0.0, 8.0 - float(candidate.get("distance", 0)))
		var role_pressure: float = _role_target_weight(str(candidate.get("role", "")))
		var jitter: float = rng.randf_range(0.0, 16.0)
		var score: float = hp_pressure + distance_pressure + role_pressure + jitter
		if score > best_score:
			best_score = score
			best_index = int(candidate.get("index", -1))
	return best_index

func choose_movement_path(options: Array[Dictionary]) -> Array[Vector2i]:
	if options.is_empty():
		return []

	var best_path: Array[Vector2i] = []
	var best_score: float = -99999.0
	for option in options:
		var path: Array[Vector2i] = option.get("path", [])
		if path.size() <= 1:
			continue
		var score := float(option.get("score", 0.0)) + rng.randf_range(0.0, 18.0)
		if score > best_score:
			best_score = score
			best_path = path
	return best_path

func _role_target_weight(role: String) -> float:
	if role == "Mage":
		return 8.0
	if role == "Cleric":
		return 6.0
	if role == "Archer":
		return 4.0
	return 0.0
