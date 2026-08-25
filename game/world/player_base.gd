class_name PlayerBase
extends Node2D

signal selected(base_node: PlayerBase)

const ENEMY_FACTION_TINT: Color = Color("#ff947d")

@onready var interaction: Area2D = $Interaction
@onready var sprite: Sprite2D = $Sprite
@onready var level_label: Label = $LevelLabel

var owner_peer_id: int = 0
var territory_id: int = 0
var base_level: int = 1

func _ready() -> void:
	interaction.input_event.connect(_on_input_event)

func configure(new_owner_peer_id: int, new_territory_id: int, local_control: bool, hostile_to_local: bool) -> void:
	owner_peer_id = new_owner_peer_id
	territory_id = new_territory_id
	sprite.self_modulate = ENEMY_FACTION_TINT if hostile_to_local else Color.WHITE
	interaction.input_pickable = local_control
	set_level(1)

func set_level(new_level: int) -> void:
	base_level = clampi(new_level, 1, BaseProgression.MAX_LEVEL)
	level_label.text = "基地 Lv.%d" % base_level

func _on_input_event(viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	selected.emit(self)
	viewport.set_input_as_handled()
