@tool
extends Node2D

const TILE_SIZE: int = 32
const GRID_MARK_INTERVAL: int = 5

@onready var player_label: Label = $PlayerLabel

@export var player_id: int = 1
@export var cell_rect: Rect2i = Rect2i(0, 0, 20, 20)
@export var territory_color: Color = Color.WHITE
var _pixel_size: Vector2 = Vector2.ZERO

func configure(new_player_id: int, new_cell_rect: Rect2i, new_color: Color) -> void:
	player_id = new_player_id
	cell_rect = new_cell_rect
	territory_color = new_color
	_apply_configuration()

func _ready() -> void:
	_apply_configuration()

func _apply_configuration() -> void:
	position = Vector2(cell_rect.position * TILE_SIZE)
	_pixel_size = Vector2(cell_rect.size * TILE_SIZE)
	if is_node_ready():
		_update_label()
	queue_redraw()

func _draw() -> void:
	if _pixel_size == Vector2.ZERO:
		return
	var fill_color: Color = territory_color
	fill_color.a = 0.07
	draw_rect(Rect2(Vector2.ZERO, _pixel_size), fill_color, true)
	var grid_color: Color = territory_color
	grid_color.a = 0.22
	for tile_x: int in range(GRID_MARK_INTERVAL, cell_rect.size.x, GRID_MARK_INTERVAL):
		var x: float = float(tile_x * TILE_SIZE)
		draw_line(Vector2(x, 0.0), Vector2(x, _pixel_size.y), grid_color, 1.0)
	for tile_y: int in range(GRID_MARK_INTERVAL, cell_rect.size.y, GRID_MARK_INTERVAL):
		var y: float = float(tile_y * TILE_SIZE)
		draw_line(Vector2(0.0, y), Vector2(_pixel_size.x, y), grid_color, 1.0)
	draw_rect(Rect2(Vector2.ZERO, _pixel_size), territory_color, false, 3.0)

func _update_label() -> void:
	player_label.text = "玩家%d领地 · 20×20" % player_id
	player_label.position = Vector2((_pixel_size.x - 180.0) / 2.0, 6.0)
	player_label.size = Vector2(180.0, 26.0)
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_color_override(&"font_color", territory_color.lightened(0.35))
