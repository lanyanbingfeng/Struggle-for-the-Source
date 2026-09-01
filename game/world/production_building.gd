class_name ProductionBuilding
extends Node2D

signal production_ready(building: ProductionBuilding, resource_type: StringName, amount: int)
signal construction_completed(building: ProductionBuilding)
signal interaction_requested(building: ProductionBuilding)
signal collection_requested(building: ProductionBuilding)

const UNDER_CONSTRUCTION_TEXTURE: Texture2D = preload("res://art/structures/structure_under_construction_imagegen_2x2.png")
const RESOURCE_ICONS: Dictionary = {
	&"gold": preload("res://art/ui/resource_icons/resource_gold.png"),
	&"wood": preload("res://art/ui/resource_icons/resource_wood.png"),
	&"stone": preload("res://art/ui/resource_icons/resource_stone.png"),
	&"iron": preload("res://art/ui/resource_icons/resource_iron.png"),
}

@onready var sprite: Sprite2D = $Sprite
@onready var icon_label: Label = $IconLabel
@onready var construction_bar: ProgressBar = $ConstructionBar
@onready var construction_label: Label = $ConstructionLabel
@onready var interaction_area: Area2D = $InteractionArea
@onready var bubble_area: Area2D = $CollectionBubble
@onready var bubble_icon: Sprite2D = $CollectionBubble/Icon
@onready var bubble_glyph: Label = $CollectionBubble/ResourceGlyph
@onready var bubble_label: Label = $CollectionBubble/Amount

var building_id: int = 0
var owner_peer_id: int = 0
var territory_id: int = 0
var definition: BuildingDefinition
var simulation_enabled: bool = false
var construction_complete: bool = false
var building_level: int = 1
var _construction_elapsed: float = 0.0
var _production_elapsed: float = 0.0
var pending_amount: int = 0
var collection_visible_to_local: bool = true

func _ready() -> void:
	interaction_area.input_event.connect(_on_interaction_input)
	bubble_area.input_event.connect(_on_bubble_input)

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
	construction_complete = false
	building_level = 1
	_construction_elapsed = 0.0
	_production_elapsed = 0.0
	pending_amount = 0
	bubble_icon.texture = RESOURCE_ICONS.get(definition.production_resource_type) as Texture2D
	_fit_bubble_icon()
	sprite.texture = UNDER_CONSTRUCTION_TEXTURE
	sprite.modulate = Color.WHITE
	icon_label.hide()
	construction_bar.max_value = definition.construction_seconds
	construction_bar.value = 0.0
	construction_bar.show()
	construction_label.show()
	_update_construction_ui()
	_update_collection_bubble()

func _process(delta: float) -> void:
	if definition == null:
		return
	if not construction_complete:
		_construction_elapsed = minf(definition.construction_seconds, _construction_elapsed + delta)
		_update_construction_ui()
		if _construction_elapsed >= definition.construction_seconds:
			_finish_construction()
		return
	if not simulation_enabled or definition.production_amount <= 0 or definition.production_resource_type.is_empty():
		return
	_production_elapsed += delta
	while _production_elapsed >= definition.production_interval_seconds:
		_production_elapsed -= definition.production_interval_seconds
		pending_amount += definition.production_amount * building_level
		_update_collection_bubble()
		production_ready.emit(self, definition.production_resource_type, pending_amount)

func set_building_level(level: int) -> void:
	if definition == null:
		return
	building_level = clampi(level, 1, definition.max_level)
	_update_collection_bubble()

func get_upgrade_iron_cost() -> int:
	return definition.upgrade_iron_cost(building_level) if definition != null else 0

func force_finish_construction() -> void:
	_finish_construction()

func _finish_construction() -> void:
	if construction_complete:
		return
	construction_complete = true
	sprite.texture = definition.texture
	sprite.modulate = definition.tint
	icon_label.hide()
	construction_bar.hide()
	construction_label.hide()
	_update_collection_bubble()
	if simulation_enabled:
		construction_completed.emit(self)

func _update_construction_ui() -> void:
	if definition == null:
		return
	construction_bar.value = _construction_elapsed
	construction_label.text = "剩余 %d 秒" % ceili(get_remaining_construction_seconds())

func set_pending_amount(amount: int) -> void:
	pending_amount = maxi(0, amount)
	_update_collection_bubble()

func set_resource_icon(texture: Texture2D) -> void:
	bubble_icon.texture = texture
	_fit_bubble_icon()
	_update_collection_bubble()

func _fit_bubble_icon() -> void:
	if bubble_icon.texture == null:
		bubble_icon.scale = Vector2.ONE
		return
	var texture_size: Vector2 = bubble_icon.texture.get_size()
	var longest_edge: float = maxf(texture_size.x, texture_size.y)
	bubble_icon.scale = Vector2.ONE * (14.0 / longest_edge if longest_edge > 0.0 else 1.0)

func set_collection_visible_to_local(enabled: bool) -> void:
	collection_visible_to_local = enabled
	_update_collection_bubble()

func take_pending_amount() -> int:
	var amount: int = pending_amount
	pending_amount = 0
	_update_collection_bubble()
	return amount

func get_remaining_construction_seconds() -> float:
	return maxf(0.0, definition.construction_seconds - _construction_elapsed) if definition != null else 0.0

func get_construction_progress() -> float:
	if definition == null or definition.construction_seconds <= 0.0:
		return 1.0
	return clampf(_construction_elapsed / definition.construction_seconds, 0.0, 1.0)

func get_runtime_save_state() -> Dictionary:
	return {
		"construction_complete": construction_complete,
		"construction_elapsed": _construction_elapsed,
		"production_elapsed": _production_elapsed,
	}

func restore_runtime_save_state(state: Dictionary) -> void:
	if definition == null:
		return
	_construction_elapsed = clampf(float(state.get("construction_elapsed", 0.0)), 0.0, definition.construction_seconds)
	_production_elapsed = maxf(0.0, float(state.get("production_elapsed", 0.0)))
	if bool(state.get("construction_complete", false)):
		var previous_simulation_enabled: bool = simulation_enabled
		simulation_enabled = false
		force_finish_construction()
		simulation_enabled = previous_simulation_enabled
	else:
		construction_complete = false
		_update_construction_ui()

func _update_collection_bubble() -> void:
	if not is_instance_valid(bubble_area) or not is_instance_valid(bubble_label):
		return
	var visible_bubble: bool = collection_visible_to_local and construction_complete and definition != null and not definition.production_resource_type.is_empty() and pending_amount > 0
	bubble_area.visible = visible_bubble
	bubble_area.input_pickable = visible_bubble
	bubble_label.text = str(pending_amount) if pending_amount <= 999 else "999+"
	if definition != null:
		bubble_glyph.text = _resource_glyph(definition.production_resource_type)
		bubble_glyph.visible = bubble_icon.texture == null

func _resource_glyph(resource_type: StringName) -> String:
	match resource_type:
		&"gold": return "金"
		&"wood": return "木"
		&"stone": return "石"
		&"iron": return "铁"
		_: return "资"

func _on_interaction_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	get_viewport().set_input_as_handled()
	interaction_requested.emit(self)

func _on_bubble_input(viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed or pending_amount <= 0:
		return
	viewport.set_input_as_handled()
	collection_requested.emit(self)
