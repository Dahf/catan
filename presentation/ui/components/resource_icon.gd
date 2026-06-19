class_name ResourceIcon
extends Control
## Einfaches, prozedural gezeichnetes Icon pro Ressource (kein Bild-Asset
## nötig). Ersetzt die reinen Buchstaben-Kürzel auf den Ressourcen-Chips
## durch eine kleine, wiedererkennbare Silhouette.

@export var resource_id: StringName = &"":
	set(v):
		resource_id = v
		queue_redraw()

@export var icon_color: Color = Color.WHITE:
	set(v):
		icon_color = v
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(14, 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := size
	match resource_id:
		&"wood":
			_draw_tree(s)
		&"brick":
			_draw_brick(s)
		&"ore":
			_draw_ore(s)
		&"grain":
			_draw_grain(s)
		&"wool":
			_draw_wool(s)
		&"plank":
			_draw_plank(s)
		&"tool":
			_draw_tool(s)
		_:
			draw_circle(s / 2.0, s.x * 0.4, icon_color)


func _draw_tree(s: Vector2) -> void:
	var trunk_w := s.x * 0.16
	draw_rect(Rect2(s.x / 2.0 - trunk_w / 2.0, s.y * 0.72, trunk_w, s.y * 0.28), icon_color)
	draw_polygon(PackedVector2Array([
		Vector2(s.x * 0.5, s.y * 0.05),
		Vector2(s.x * 0.85, s.y * 0.55),
		Vector2(s.x * 0.15, s.y * 0.55),
	]), PackedColorArray([icon_color]))
	draw_polygon(PackedVector2Array([
		Vector2(s.x * 0.5, s.y * 0.3),
		Vector2(s.x * 0.92, s.y * 0.8),
		Vector2(s.x * 0.08, s.y * 0.8),
	]), PackedColorArray([icon_color]))


func _draw_brick(s: Vector2) -> void:
	var gap := s.x * 0.08
	draw_rect(Rect2(gap, gap, s.x * 0.5 - gap * 1.5, s.y * 0.4 - gap), icon_color)
	draw_rect(Rect2(s.x * 0.5 + gap * 0.5, gap, s.x * 0.5 - gap * 1.5, s.y * 0.4 - gap), icon_color)
	draw_rect(Rect2(gap * 2.0, s.y * 0.5, s.x * 0.5 - gap, s.y * 0.4 - gap), icon_color)
	draw_rect(Rect2(s.x * 0.5 + gap, s.y * 0.5, s.x * 0.5 - gap * 2.0, s.y * 0.4 - gap), icon_color)


func _draw_ore(s: Vector2) -> void:
	draw_polygon(PackedVector2Array([
		Vector2(s.x * 0.5, s.y * 0.05),
		Vector2(s.x * 0.95, s.y * 0.5),
		Vector2(s.x * 0.5, s.y * 0.95),
		Vector2(s.x * 0.05, s.y * 0.5),
	]), PackedColorArray([icon_color]))


func _draw_grain(s: Vector2) -> void:
	var base := Vector2(s.x * 0.5, s.y * 0.95)
	draw_line(base, Vector2(s.x * 0.5, s.y * 0.15), icon_color, 1.5)
	var fractions : Array[float] = [0.25, 0.45, 0.65]
	for t in fractions:
		var y : float = s.y * (0.95 - t * 0.8)
		draw_line(Vector2(s.x * 0.5, y), Vector2(s.x * 0.5 - s.x * 0.32, y - s.y * 0.18), icon_color, 1.5)
		draw_line(Vector2(s.x * 0.5, y), Vector2(s.x * 0.5 + s.x * 0.32, y - s.y * 0.18), icon_color, 1.5)


func _draw_wool(s: Vector2) -> void:
	draw_circle(Vector2(s.x * 0.35, s.y * 0.55), s.x * 0.28, icon_color)
	draw_circle(Vector2(s.x * 0.65, s.y * 0.55), s.x * 0.28, icon_color)
	draw_circle(Vector2(s.x * 0.5, s.y * 0.35), s.x * 0.28, icon_color)


func _draw_plank(s: Vector2) -> void:
	draw_rect(Rect2(s.x * 0.05, s.y * 0.35, s.x * 0.9, s.y * 0.3), icon_color)
	draw_line(Vector2(s.x * 0.05, s.y * 0.5), Vector2(s.x * 0.95, s.y * 0.5), Color(0, 0, 0, 0.3), 1.0)


func _draw_tool(s: Vector2) -> void:
	draw_rect(Rect2(s.x * 0.15, s.y * 0.45, s.x * 0.7, s.y * 0.16), icon_color)
	draw_circle(Vector2(s.x * 0.22, s.y * 0.53), s.x * 0.18, icon_color)
	draw_rect(Rect2(s.x * 0.78, s.y * 0.42, s.x * 0.12, s.y * 0.22), icon_color)
