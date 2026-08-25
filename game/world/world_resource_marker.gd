@tool
class_name WorldResourceMarker
extends Node2D

var resource_type: StringName = &"tree"
var territory_id: int = 0
var resource_id: int = 0

func configure(new_resource_id: int, new_resource_type: StringName, texture: Texture2D) -> void:
	resource_id = new_resource_id
	resource_type = new_resource_type
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if resource_type == &"tree":
		sprite.centered = false
		sprite.position = Vector2(-16.0, -64.0)
	else:
		sprite.position = Vector2(0.0, -16.0)
	add_child(sprite)
