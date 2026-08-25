extends Node

signal resources_changed(gold: int, wood: int, stone: int, iron: int, gold_ore: int, diamond: int)

const DEVELOPMENT_GOLD: int = 9999
const TREE_WOOD_REWARD: int = 10
const TREE_GOLD_COST: int = 1
const STONE_REWARD: int = 8
const STONE_GOLD_COST: int = 1

var gold: int = DEVELOPMENT_GOLD
var wood: int = 0
var stone: int = 0
var iron: int = 0
var gold_ore: int = 0
var diamond: int = 0

func _ready() -> void:
	reset_development_state()

func reset_development_state() -> void:
	gold = DEVELOPMENT_GOLD
	wood = 0
	stone = 0
	iron = 0
	gold_ore = 0
	diamond = 0
	_emit_resources_changed()

func apply_tree_harvest() -> void:
	wood += TREE_WOOD_REWARD
	gold = maxi(0, gold - TREE_GOLD_COST)
	_emit_resources_changed()
	print("树木倒下：木材 +", TREE_WOOD_REWARD, "，金币 -", TREE_GOLD_COST)

func apply_stone_harvest() -> void:
	stone += STONE_REWARD
	gold = maxi(0, gold - STONE_GOLD_COST)
	_emit_resources_changed()
	print("石头采完：石头 +", STONE_REWARD, "，金币 -", STONE_GOLD_COST)

func set_state(new_gold: int, new_wood: int, new_stone: int, new_iron: int, new_gold_ore: int = 0, new_diamond: int = 0) -> void:
	gold = maxi(0, new_gold)
	wood = maxi(0, new_wood)
	stone = maxi(0, new_stone)
	iron = maxi(0, new_iron)
	gold_ore = maxi(0, new_gold_ore)
	diamond = maxi(0, new_diamond)
	_emit_resources_changed()

func get_state() -> Dictionary:
	return {"gold": gold, "wood": wood, "stone": stone, "iron": iron, "gold_ore": gold_ore, "diamond": diamond}

func _emit_resources_changed() -> void:
	resources_changed.emit(gold, wood, stone, iron, gold_ore, diamond)
