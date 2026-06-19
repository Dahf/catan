class_name TierMeter
extends Control
## Horizontale Versorgungs-Anzeige für Settlement.supplied_streak.
## Zeigt einen zentrierten Balken: grün nach rechts Richtung Aufstieg (+max),
## rot nach links Richtung Abstieg (-max). Eigenes _draw(), da Godot keinen
## eingebauten "bidirektionalen" Range-Indikator besitzt.

@export var min_value: int = -3
@export var max_value: int = 3

var value: int = 0:
	set(v):
		value = clampi(v, min_value, max_value)
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(160, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var mid := w / 2.0

	draw_rect(Rect2(Vector2.ZERO, size), CatanPalette.PARCHMENT_DARK)

	if value > 0 and max_value > 0:
		var frac := float(value) / float(max_value)
		draw_rect(Rect2(Vector2(mid, 0), Vector2(frac * mid, h)), CatanPalette.FOREST_GREEN)
	elif value < 0 and min_value < 0:
		var frac := float(-value) / float(-min_value)
		draw_rect(Rect2(Vector2(mid - frac * mid, 0), Vector2(frac * mid, h)), CatanPalette.LEATHER_RED)

	draw_line(Vector2(mid, 0), Vector2(mid, h), CatanPalette.WOOD_BROWN, 2.0)
	draw_rect(Rect2(Vector2.ZERO, size), CatanPalette.WOOD_BROWN, false, 2.0)
