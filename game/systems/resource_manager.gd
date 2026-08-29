extends Node

signal resources_changed(gold: int, wood: int, stone: int, iron: int, summon_token: int, skill_experience: int, experience: int)

const STARTING_GOLD: int = 700
const TREE_WOOD_REWARD: int = 10
const STONE_REWARD: int = 8

var gold: int = STARTING_GOLD
var wood: int = 0
var stone: int = 0
var iron: int = 0
var summon_token: int = 0
var skill_experience: int = 0
var experience: int = 0

func _ready() -> void:
	reset_development_state()

func reset_development_state() -> void:
	gold = STARTING_GOLD
	wood = 0
	stone = 0
	iron = 0
	summon_token = 0
	skill_experience = 0
	experience = 0
	_emit_resources_changed()

func apply_tree_harvest() -> void:
	wood += TREE_WOOD_REWARD
	_emit_resources_changed()
	print("树木倒下：木材 +", TREE_WOOD_REWARD)

func apply_stone_harvest() -> void:
	stone += STONE_REWARD
	_emit_resources_changed()
	print("石头采完：石头 +", STONE_REWARD)

func set_state(new_gold: int, new_wood: int, new_stone: int, new_iron: int, new_summon_token: int = 0, new_skill_experience: int = 0, new_experience: int = 0) -> void:
	gold = maxi(0, new_gold)
	wood = maxi(0, new_wood)
	stone = maxi(0, new_stone)
	iron = maxi(0, new_iron)
	summon_token = maxi(0, new_summon_token)
	skill_experience = maxi(0, new_skill_experience)
	experience = maxi(0, new_experience)
	_emit_resources_changed()

func get_state() -> Dictionary:
	return {"gold": gold, "wood": wood, "stone": stone, "iron": iron, "summon_token": summon_token, "skill_experience": skill_experience, "experience": experience}

func _emit_resources_changed() -> void:
	resources_changed.emit(gold, wood, stone, iron, summon_token, skill_experience, experience)
