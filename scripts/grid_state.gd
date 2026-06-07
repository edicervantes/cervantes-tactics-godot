extends RefCounted
class_name TacticalGridState

var grid_size := Vector2i(8, 7)
var crystal_grid := Vector2i(4, 3)
var obstacles: Array[Vector2i] = []

func configure(next_grid_size: Vector2i, next_crystal_grid: Vector2i, next_obstacles: Array[Vector2i]) -> void:
	grid_size = next_grid_size
	crystal_grid = next_crystal_grid
	obstacles = next_obstacles.duplicate()

func movement_path_for(units: Array[Node], unit: Node, grid: Vector2i) -> Array[Vector2i]:
	if grid == unit.grid or is_cell_blocked(units, grid, unit):
		return []
	var path := path_between(units, unit.grid, grid, unit)
	if path.size() <= 1 or path.size() - 1 > unit.move:
		return []
	return path

func movement_cells_for(units: Array[Node], unit: Node) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in grid_size.y:
		for x in grid_size.x:
			var grid := Vector2i(x, y)
			if not movement_path_for(units, unit, grid).is_empty():
				cells.append(grid)
	return cells

func path_between(units: Array[Node], from_cell: Vector2i, to_cell: Vector2i, moving_unit: Node = null) -> Array[Vector2i]:
	if is_cell_blocked(units, from_cell, moving_unit) or is_cell_blocked(units, to_cell, moving_unit):
		return []
	var pathfinder := build_pathfinder(units, moving_unit)
	return pathfinder.get_id_path(from_cell, to_cell)

func build_pathfinder(units: Array[Node], moving_unit: Node = null) -> AStarGrid2D:
	var pathfinder := AStarGrid2D.new()
	pathfinder.region = Rect2i(Vector2i.ZERO, grid_size)
	pathfinder.cell_size = Vector2.ONE
	pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	pathfinder.update()

	for obstacle in obstacles:
		if is_inside_grid(obstacle):
			pathfinder.set_point_solid(obstacle, true)

	if is_inside_grid(crystal_grid):
		pathfinder.set_point_solid(crystal_grid, true)

	for unit in units:
		if unit == moving_unit or not unit.is_alive() or not is_inside_grid(unit.grid):
			continue
		if not unit.blocks_movement:
			continue
		pathfinder.set_point_solid(unit.grid, true)

	return pathfinder

func is_cell_blocked(units: Array[Node], grid: Vector2i, moving_unit: Node = null) -> bool:
	if not is_inside_grid(grid):
		return true
	if grid == crystal_grid or is_obstacle(grid):
		return true
	var occupant := unit_at(units, grid)
	return occupant != -1 and units[occupant].blocks_movement and (moving_unit == null or units[occupant] != moving_unit)

func attack_cells_for(units: Array[Node], attacker: Node, target_grid: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in grid_size.y:
		for x in grid_size.x:
			var grid := Vector2i(x, y)
			if is_cell_blocked(units, grid, attacker):
				continue
			if distance(grid, target_grid) <= attacker.attack_range:
				cells.append(grid)
	return cells

func threat_cells_for_team(units: Array[Node], team: String) -> Array[Vector2i]:
	var threat_lookup := {}
	for unit in units:
		if unit.team != team or not unit.is_alive():
			continue
		for cell in action_cells_for_unit(units, unit, unit.attack_range):
			threat_lookup[cell] = true

	var cells: Array[Vector2i] = []
	for cell in threat_lookup.keys():
		cells.append(cell)
	return cells

func action_cells_for_unit(units: Array[Node], unit: Node, action_range: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in grid_size.y:
		for x in grid_size.x:
			var grid := Vector2i(x, y)
			if is_cell_blocked(units, grid, unit):
				continue
			if is_in_range(unit.grid, grid, action_range):
				cells.append(grid)
	return cells

func action_range_cells(origin: Vector2i, action_range: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in grid_size.y:
		for x in grid_size.x:
			var grid := Vector2i(x, y)
			if grid == origin or is_static_blocker(grid):
				continue
			if distance(origin, grid) <= action_range:
				cells.append(grid)
	return cells

func unit_indices_in_range(units: Array[Node], origin: Vector2i, team: String, max_range: int, excluded_index := -1) -> Array[int]:
	var indices: Array[int] = []
	for i in units.size():
		if i == excluded_index or units[i].team != team or not units[i].is_alive():
			continue
		if is_in_range(origin, units[i].grid, max_range):
			indices.append(i)
	return indices

func nearest_open_cell(units: Array[Node], requested_grid: Vector2i, moving_unit: Node = null) -> Vector2i:
	if not is_cell_blocked(units, requested_grid, moving_unit):
		return requested_grid

	var best_grid := requested_grid
	var best_distance := INF
	for y in grid_size.y:
		for x in grid_size.x:
			var candidate := Vector2i(x, y)
			if is_cell_blocked(units, candidate, moving_unit):
				continue
			var candidate_distance := distance(requested_grid, candidate)
			if candidate_distance < best_distance:
				best_distance = candidate_distance
				best_grid = candidate
	return best_grid

func adjacent_cells(grid: Vector2i, only_open := false, units: Array[Node] = [], moving_unit: Node = null) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [
		grid + Vector2i(1, 0),
		grid + Vector2i(-1, 0),
		grid + Vector2i(0, 1),
		grid + Vector2i(0, -1)
	]
	if not only_open:
		return cells

	var open_cells: Array[Vector2i] = []
	for cell in cells:
		if not is_cell_blocked(units, cell, moving_unit):
			open_cells.append(cell)
	return open_cells

func unit_at(units: Array[Node], grid: Vector2i) -> int:
	for i in units.size():
		if units[i].grid == grid and units[i].is_alive():
			return i
	return -1

func is_static_blocker(grid: Vector2i) -> bool:
	return not is_inside_grid(grid) or grid == crystal_grid or is_obstacle(grid)

func is_obstacle(grid: Vector2i) -> bool:
	return obstacles.has(grid)

func is_inside_grid(grid: Vector2i) -> bool:
	return grid.x >= 0 and grid.y >= 0 and grid.x < grid_size.x and grid.y < grid_size.y

func distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func is_in_range(a: Vector2i, b: Vector2i, max_range: int) -> bool:
	return distance(a, b) <= max_range
