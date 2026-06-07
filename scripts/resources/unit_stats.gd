extends Resource
class_name UnitStats

@export var unit_name := ""
@export var role := ""
@export var level := 1
@export var exp := 0
@export var exp_to_next := 100
@export var max_hp := 1
@export var move := 1
@export var attack := 1
@export var attack_range := 1
@export var magic_aoe_radius := 0
@export var heal := 0
@export var team_heal := 0
@export var limit_charge_max := 0
@export var limit_damage_multiplier := 1
@export var trap_detection_radius := 0
@export var evasion_aura_radius := 0
@export var evasion_damage_reduction := 0
@export var is_noncombatant := false
@export var blocks_movement := true
@export var spiritual_aura_radius := 0
@export var spiritual_aura_heal := 0
@export var hint := ""
@export var unit_color := Color.WHITE
@export var portrait_texture: Texture2D
@export var standee_texture: Texture2D
@export var standee_se: Texture2D
@export var standee_sw: Texture2D
@export var standee_ne: Texture2D
@export var standee_nw: Texture2D
@export var standee_scale := 0.23
