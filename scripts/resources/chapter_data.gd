extends Resource
class_name ChapterData

@export var chapter_name := ""
@export var objective_text := ""
@export var objective_short := ""
@export var victory_condition := ""
@export var defeat_condition := ""
@export var tactical_hint := ""
@export var opening_tutorial := ""
@export var move_tutorial := ""
@export var attack_tutorial := ""
@export var special_tutorial := ""
@export var defend_tutorial := ""
@export var wait_tutorial := ""
@export var enemy_turn_tutorial := ""
@export var player_turn_tutorial := ""
@export var grid_size := Vector2i(8, 7)
@export var crystal_grid := Vector2i(4, 3)
@export var crystal_hp := 4
@export var crystal_color := Color("#9fd4ff")
@export var diego_magic_unstable := false
@export var music_stream: AudioStream
@export var obstacles: Array[Vector2i] = []
@export var trap_cells: Array[Vector2i] = []
@export var hidden_path_cells: Array[Vector2i] = []
@export var terrain_cells: Array[Dictionary] = []
@export var prop_cells: Array[Dictionary] = []
@export var decoration_cells: Array[Dictionary] = []
@export var unit_spawns: Array[Dictionary] = []
@export var intro_lines: Array[Dictionary] = []
@export var enemy_turn_lines: Array[Dictionary] = []
@export var first_enemy_defeated_lines: Array[Dictionary] = []
@export var first_player_hurt_lines: Array[Dictionary] = []
@export var crystal_low_hp_lines: Array[Dictionary] = []
@export var first_level_up_lines: Array[Dictionary] = []
@export var hidden_path_revealed_lines: Array[Dictionary] = []
@export var outro_win_lines: Array[Dictionary] = []
@export var outro_lose_lines: Array[Dictionary] = []
