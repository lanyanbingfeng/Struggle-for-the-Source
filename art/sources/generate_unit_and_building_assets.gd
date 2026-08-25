extends SceneTree

const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)

func _init() -> void:
	_generate_swordsman()
	_generate_builder()
	_generate_workshop()
	quit()

func _new_image(size: Vector2i) -> Image:
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(TRANSPARENT)
	return image

func _rect(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)

func _line(image: Image, from: Vector2i, to: Vector2i, color: Color, thickness: int = 1) -> void:
	var x0 := from.x
	var y0 := from.y
	var x1 := to.x
	var y1 := to.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var error := dx + dy
	while true:
		for oy: int in range(-(thickness >> 1), (thickness + 1) >> 1):
			for ox: int in range(-(thickness >> 1), (thickness + 1) >> 1):
				var point := Vector2i(x0 + ox, y0 + oy)
				if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height():
					image.set_pixelv(point, color)
		if x0 == x1 and y0 == y1:
			break
		var doubled := error * 2
		if doubled >= dy:
			error += dy
			x0 += sx
		if doubled <= dx:
			error += dx
			y0 += sy

func _polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i.ZERO
	for point: Vector2 in points:
		minimum.x = mini(minimum.x, floori(point.x))
		minimum.y = mini(minimum.y, floori(point.y))
		maximum.x = maxi(maximum.x, ceili(point.x))
		maximum.y = maxi(maximum.y, ceili(point.y))
	for y: int in range(maxi(0, minimum.y), mini(image.get_height(), maximum.y + 1)):
		for x: int in range(maxi(0, minimum.x), mini(image.get_width(), maximum.x + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				image.set_pixel(x, y, color)
	for index: int in points.size():
		_line(image, Vector2i(points[index]), Vector2i(points[(index + 1) % points.size()]), color.darkened(0.45))

func _save(image: Image, relative_path: String) -> void:
	var error := image.save_png(ProjectSettings.globalize_path(relative_path))
	if error != OK:
		push_error("Failed to save %s: %s" % [relative_path, error_string(error)])

func _generate_swordsman() -> void:
	var image := _new_image(Vector2i(32, 32))
	var outline := Color("#24160f")
	var leather_dark := Color("#5b3522")
	var leather := Color("#8b5430")
	var leather_light := Color("#c28749")
	var skin := Color("#eaa06a")
	var steel_dark := Color("#65717b")
	var steel := Color("#c9d3d8")
	var steel_light := Color("#f6f3d8")
	var crimson := Color("#c42e35")
	# Fast forward-leaning legs.
	_rect(image, Rect2i(14, 22, 5, 8), outline)
	_rect(image, Rect2i(15, 22, 3, 7), leather_dark)
	_rect(image, Rect2i(20, 21, 5, 7), outline)
	_rect(image, Rect2i(21, 22, 3, 5), leather)
	_rect(image, Rect2i(13, 28, 6, 2), leather_light)
	_rect(image, Rect2i(21, 26, 6, 2), leather_light)
	# Torso, shoulder and sword arm.
	_rect(image, Rect2i(11, 12, 13, 12), outline)
	_rect(image, Rect2i(13, 13, 9, 10), leather)
	_rect(image, Rect2i(12, 14, 3, 6), leather_light)
	_rect(image, Rect2i(21, 14, 5, 5), outline)
	_rect(image, Rect2i(22, 15, 3, 3), leather_light)
	_rect(image, Rect2i(8, 15, 5, 8), outline)
	_rect(image, Rect2i(9, 16, 3, 6), leather)
	_rect(image, Rect2i(8, 21, 4, 3), skin)
	# Head and swept hair.
	_rect(image, Rect2i(13, 5, 11, 9), outline)
	_rect(image, Rect2i(15, 7, 8, 6), skin)
	_rect(image, Rect2i(12, 4, 11, 5), leather_dark)
	_rect(image, Rect2i(14, 3, 8, 3), leather)
	_rect(image, Rect2i(20, 6, 5, 3), leather_dark)
	image.set_pixel(21, 9, Color("#efe2c6"))
	# Crimson scarf and belt.
	_rect(image, Rect2i(13, 12, 10, 3), crimson.darkened(0.35))
	_rect(image, Rect2i(15, 13, 8, 3), crimson)
	_rect(image, Rect2i(13, 20, 10, 2), outline)
	_rect(image, Rect2i(15, 20, 6, 1), Color("#d7a94d"))
	# Diagonal short sword with a clear 1px highlight.
	_line(image, Vector2i(9, 21), Vector2i(3, 30), outline, 5)
	_line(image, Vector2i(8, 22), Vector2i(3, 29), steel_dark, 3)
	_line(image, Vector2i(7, 22), Vector2i(3, 28), steel_light, 1)
	_line(image, Vector2i(7, 20), Vector2i(11, 23), Color("#d7a94d"), 2)
	image.set_pixel(12, 23, outline)
	_save(image, "res://art/units/unit_swordsman_1x1.png")

func _generate_builder() -> void:
	var image := _new_image(Vector2i(32, 32))
	var outline := Color("#2b1b12")
	var coat_dark := Color("#9a5b18")
	var coat := Color("#d89022")
	var coat_light := Color("#f4bd3e")
	var leather := Color("#704127")
	var skin := Color("#d98d58")
	var paper := Color("#efe3c1")
	# Boots and working coat.
	_rect(image, Rect2i(11, 22, 6, 8), outline)
	_rect(image, Rect2i(12, 23, 4, 6), leather)
	_rect(image, Rect2i(20, 22, 6, 8), outline)
	_rect(image, Rect2i(21, 23, 4, 6), leather)
	_rect(image, Rect2i(10, 12, 16, 13), outline)
	_rect(image, Rect2i(12, 13, 12, 11), coat)
	_rect(image, Rect2i(12, 14, 3, 8), coat_light)
	_rect(image, Rect2i(12, 20, 12, 3), leather)
	image.set_pixel(18, 21, Color("#cbd1d0"))
	# Head and yellow construction cap.
	_rect(image, Rect2i(13, 6, 11, 8), outline)
	_rect(image, Rect2i(15, 8, 8, 5), skin)
	_rect(image, Rect2i(12, 4, 12, 5), outline)
	_rect(image, Rect2i(14, 4, 9, 4), coat_light)
	_rect(image, Rect2i(12, 8, 14, 2), coat)
	image.set_pixel(21, 10, Color("#e6d9bf"))
	# Hammer at left.
	_line(image, Vector2i(11, 16), Vector2i(5, 24), outline, 4)
	_line(image, Vector2i(10, 16), Vector2i(5, 23), leather, 2)
	_rect(image, Rect2i(2, 21, 7, 5), outline)
	_rect(image, Rect2i(3, 22, 5, 3), Color("#8a9497"))
	_rect(image, Rect2i(3, 22, 2, 2), Color("#d9ded5"))
	# Rolled blueprint at right.
	_line(image, Vector2i(24, 15), Vector2i(29, 22), outline, 5)
	_line(image, Vector2i(24, 15), Vector2i(29, 22), paper, 3)
	image.set_pixel(27, 19, Color("#3d69a8"))
	image.set_pixel(28, 20, Color("#3d69a8"))
	_save(image, "res://art/units/unit_builder_1x1.png")

func _generate_workshop() -> void:
	var image := _new_image(Vector2i(64, 64))
	var outline := Color("#25170e")
	var stone_dark := Color("#596164")
	var stone := Color("#899296")
	var stone_light := Color("#c4c8bd")
	var wood_dark := Color("#70401e")
	var wood := Color("#a86228")
	var wood_light := Color("#d58b39")
	var roof_dark := Color("#24496f")
	var roof := Color("#32699e")
	var roof_light := Color("#5798c7")
	# 2x2 foundation and stone plinth.
	_polygon(image, PackedVector2Array([Vector2(6, 50), Vector2(31, 38), Vector2(58, 50), Vector2(34, 63), Vector2(6, 56)]), outline)
	_polygon(image, PackedVector2Array([Vector2(8, 49), Vector2(31, 39), Vector2(56, 50), Vector2(34, 60), Vector2(8, 54)]), stone)
	_line(image, Vector2i(10, 51), Vector2i(34, 58), stone_light, 2)
	# Main timber-and-stone body.
	_rect(image, Rect2i(13, 28, 39, 25), outline)
	_rect(image, Rect2i(16, 29, 33, 22), wood_dark)
	_rect(image, Rect2i(19, 31, 27, 19), Color("#b87836"))
	_rect(image, Rect2i(16, 31, 4, 20), stone_dark)
	_rect(image, Rect2i(46, 31, 4, 20), stone_dark)
	_rect(image, Rect2i(18, 47, 30, 4), stone)
	_rect(image, Rect2i(21, 48, 8, 2), stone_light)
	# Blue roof, designed as a compact readable silhouette.
	_polygon(image, PackedVector2Array([Vector2(10, 31), Vector2(31, 15), Vector2(55, 31), Vector2(47, 38), Vector2(17, 38)]), outline)
	_polygon(image, PackedVector2Array([Vector2(13, 30), Vector2(31, 17), Vector2(52, 30), Vector2(46, 35), Vector2(18, 35)]), roof)
	_line(image, Vector2i(16, 29), Vector2i(31, 18), roof_light, 3)
	_line(image, Vector2i(31, 18), Vector2i(50, 30), roof_dark, 3)
	for x: int in range(20, 47, 7):
		_line(image, Vector2i(x, 26), Vector2i(x + 3, 34), roof_dark)
	# Door and blank resource sign plate.
	_rect(image, Rect2i(27, 39, 12, 14), outline)
	_rect(image, Rect2i(29, 41, 8, 12), wood_dark)
	image.set_pixel(35, 47, Color("#d8ad4b"))
	_rect(image, Rect2i(20, 35, 26, 8), outline)
	_rect(image, Rect2i(22, 37, 22, 4), wood_light)
	_rect(image, Rect2i(24, 37, 16, 1), Color("#efbd67"))
	# Chimney and small crane/hopper.
	_rect(image, Rect2i(39, 11, 8, 13), outline)
	_rect(image, Rect2i(41, 12, 5, 11), stone)
	_rect(image, Rect2i(41, 13, 3, 3), stone_light)
	_rect(image, Rect2i(4, 25, 6, 27), outline)
	_rect(image, Rect2i(6, 26, 3, 24), wood)
	_line(image, Vector2i(7, 27), Vector2i(20, 19), outline, 4)
	_line(image, Vector2i(7, 27), Vector2i(20, 20), wood_light, 2)
	_line(image, Vector2i(19, 20), Vector2i(19, 30), Color("#3b3330"), 1)
	_rect(image, Rect2i(15, 29, 9, 7), outline)
	_rect(image, Rect2i(17, 30, 5, 4), wood)
	_save(image, "res://art/structures/structure_resource_workshop_2x2.png")
