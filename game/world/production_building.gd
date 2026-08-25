class_name ProductionBuilding
extends Node2D

signal production_ready(owner_peer_id: int, resource_type: StringName, amount: int)

@onready var sprite: Sprite2D = $Sprite
@onready var icon_label: Label = $IconLabel

var building_id: int = 0
var owner_peer_id: int = 0
var territory_id: int = 0
var definition: BuildingDefinition
var simulation_enabled: bool = false
var _production_elapsed: float = 0.0

func configure(
	new_building_id: int,
	new_owner_peer_id: int,
	new_territory_id: int,
	new_definition: BuildingDefinition,
	should_simulate: bool
) -> void:
	building_id = new_building_id
	owner_peer_id = new_owner_peer_id
	territory_id = new_territory_id
	definition = new_definition
	simulation_enabled = should_simulate
	_production_elapsed = 0.0
	sprite.texture = definition.texture
	sprite.modulate = definition.tint
	icon_label.text = definition.icon_text

func _process(delta: float) -> void:
	if not simulation_enabled or definition == null:
		return
	_production_elapsed += delta
	while _production_elapsed >= definition.production_interval_seconds:
		_production_elapsed -= definition.production_interval_seconds
		production_ready.emit(owner_peer_id, definition.production_resource_type, definition.production_amount)
