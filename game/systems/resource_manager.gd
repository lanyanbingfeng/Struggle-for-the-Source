extends Node

signal resources_changed(gold: int, wood: int, stone: int, iron: int)

const DEVELOPMENT_GOLD: int = 9999
const TREE_WOOD_REWARD: int = 10
const TREE_GOLD_COST: int = 1

var gold: int = DEVELOPMENT_GOLD
var wood: int = 0
var stone: int = 0
var iron: int = 0

func _ready() -> void:
	reset_development_state()

func reset_development_state() -> void:
	gold = DEVELOPMENT_GOLD
	wood = 0
	stone = 0
	iron = 0
	_emit_resources_changed()

func apply_tree_harvest() -> void:
	wood += TREE_WOOD_REWARD
	gold = maxi(0, gold - TREE_GOLD_COST)
	_emit_resources_changed()
	print("树木倒下：木材 +", TREE_WOOD_REWARD, "，金币 -", TREE_GOLD_COST)

func _emit_resources_changed() -> void:
	resources_changed.emit(gold, wood, stone, iron)
