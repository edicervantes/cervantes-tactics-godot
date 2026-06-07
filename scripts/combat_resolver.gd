extends RefCounted
class_name CombatResolver

func resolve_weapon_attack(attacker: Node, target: Node, damage_reduction := 0) -> Dictionary:
	var damage_amount: int = max(1, attacker.attack - damage_reduction)
	var damage: int = target.take_damage(damage_amount)
	return {
		"damage": damage,
		"reduction": damage_reduction,
		"target_defeated": not target.is_alive()
	}

func resolve_magic_attack(caster: Node, target: Node) -> Dictionary:
	var damage: int = target.take_damage(caster.attack + 1)
	return {
		"damage": damage,
		"target_defeated": not target.is_alive()
	}

func resolve_limit_break(attacker: Node, target: Node) -> Dictionary:
	var damage: int = target.take_damage(attacker.attack * attacker.limit_damage_multiplier)
	attacker.reset_limit_charge()
	return {
		"damage": damage,
		"target_defeated": not target.is_alive()
	}

func resolve_magic_aoe(caster: Node, units: Array[Node], center_grid: Vector2i, radius: int, unstable: bool) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for i in units.size():
		var target = units[i]
		if not target.is_alive():
			continue
		if _distance(target.grid, center_grid) > radius:
			continue
		if target.team == caster.team and not unstable:
			continue
		var damage_amount: int = caster.attack + 1
		if target.team == caster.team:
			damage_amount = 1
		var damage: int = target.take_damage(damage_amount)
		hits.append({
			"index": i,
			"unit": target,
			"damage": damage,
			"target_defeated": not target.is_alive(),
			"team": target.team
		})
	return hits

func resolve_heal(healer: Node, target: Node) -> Dictionary:
	var healed: int = target.heal_amount(healer.heal)
	return {
		"healed": healed,
		"target_full_hp": target.hp >= target.max_hp
	}

func resolve_team_heal(healer: Node, units: Array[Node]) -> Array[Dictionary]:
	var heals: Array[Dictionary] = []
	for i in units.size():
		var target = units[i]
		if target.team != healer.team or not target.is_alive() or target.hp >= target.max_hp:
			continue
		var healed: int = target.heal_amount(healer.team_heal)
		heals.append({
			"index": i,
			"unit": target,
			"healed": healed,
			"target_full_hp": target.hp >= target.max_hp
		})
	return heals

func _distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
