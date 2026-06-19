class_name BuildingIcon
extends Control
## Einfaches, prozedural gezeichnetes Icon pro Bautyp (kein Bild-Asset nötig).
## Eine Silhouette pro BuildingDef.id; fällt bei unbekannter id auf ein
## generisches Kategorie-Symbol zurück.

@export var building_id: StringName = &"":
	set(v):
		building_id = v
		queue_redraw()

@export var icon_color: Color = CatanPalette.WOOD_BROWN:
	set(v):
		icon_color = v
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(32, 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := size
	match building_id:
		&"settlement":
			_draw_house(s)
		&"extractor":
			_draw_pick(s)
		&"sawmill":
			_draw_saw(s)
		&"smithy":
			_draw_anvil(s)
		_:
			draw_circle(s / 2.0, s.x * 0.35, icon_color)


func _draw_house(s: Vector2) -> void:
	draw_rect(Rect2(s.x * 0.22, s.y * 0.5, s.x * 0.56, s.y * 0.42), icon_color)
	draw_polygon(PackedVector2Array([
		Vector2(s.x * 0.5, s.y * 0.12),
		Vector2(s.x * 0.88, s.y * 0.52),
		Vector2(s.x * 0.12, s.y * 0.52),
	]), PackedColorArray([icon_color]))


func _draw_pick(s: Vector2) -> void:
	# Spitzhacke: diagonaler Stiel + gebogener Kopf.
	draw_line(Vector2(s.x * 0.25, s.y * 0.85), Vector2(s.x * 0.65, s.y * 0.2), icon_color, s.x * 0.1)
	draw_line(Vector2(s.x * 0.3, s.y * 0.22), Vector2(s.x * 0.88, s.y * 0.45), icon_color, s.x * 0.12)


func _draw_saw(s: Vector2) -> void:
	# Kreissägeblatt: Scheibe mit vier kräftigen Zähnen, Mittelloch.
	var center := s / 2.0
	draw_circle(center, s.x * 0.4, icon_color)
	var teeth := 6
	for i in teeth:
		var angle := TAU * float(i) / float(teeth)
		var dir := Vector2(cos(angle), sin(angle))
		var perp := Vector2(-dir.y, dir.x) * s.x * 0.07
		var tip := center + dir * s.x * 0.5
		draw_polygon(PackedVector2Array([
			center + dir * s.x * 0.38 + perp,
			center + dir * s.x * 0.38 - perp,
			tip,
		]), PackedColorArray([icon_color]))
	draw_circle(center, s.x * 0.14, Color(0, 0, 0, 0.3))


func _draw_anvil(s: Vector2) -> void:
	# Klassisches Anvil-Profil: breite Arbeitsfläche, Horn seitlich, Taille, Fuß.
	draw_rect(Rect2(s.x * 0.18, s.y * 0.26, s.x * 0.64, s.y * 0.16), icon_color)
	draw_polygon(PackedVector2Array([
		Vector2(s.x * 0.18, s.y * 0.3),
		Vector2(s.x * 0.18, s.y * 0.42),
		Vector2(s.x * 0.02, s.y * 0.36),
	]), PackedColorArray([icon_color]))
	draw_rect(Rect2(s.x * 0.36, s.y * 0.42, s.x * 0.28, s.y * 0.16), icon_color)
	draw_rect(Rect2(s.x * 0.22, s.y * 0.58, s.x * 0.56, s.y * 0.2), icon_color)
