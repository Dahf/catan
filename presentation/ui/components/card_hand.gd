class_name CardHand
extends Control
## Zeigt die Ressourcen des aktuellen Spielers als aufgefächerte Handkarten unten
## im Bild (eine Karte je Ressourceneinheit), so als hielte man sie in der Hand.
## Nutzt CatanPalette-Farben und die prozeduralen ResourceIcons (keine Bild-Assets).

const CARD_SIZE := Vector2(64, 92)
const MAX_SPREAD_DEG := 34.0      # maximaler Gesamt-Fächerwinkel
const PER_CARD_DEG := 5.0         # Winkel pro Karte (bis MAX_SPREAD_DEG)
const ARC_DROP := 28.0            # wie weit die Randkarten tiefer sinken (Bogen)
const BOTTOM_MARGIN := 14.0       # Abstand der Karten zum unteren Bildrand
const MIN_SPACING := 18.0
const MAX_SPACING := 46.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Vollflächig + am Ursprung (0,0) verankern, damit lokale Koordinaten den
	# Bildschirmkoordinaten entsprechen. Positioniert wird über die Fenstergröße.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	get_viewport().size_changed.connect(_layout)


## Baut die Hand neu aus dem Ressourcen-Dictionary (StringName -> int).
func set_cards(resources: Dictionary) -> void:
	# Alte Karten SOFORT aus dem Baum nehmen (nicht nur queue_free), sonst zählt
	# _layout im selben Frame alte + neue Karten mit → Karten verschieben sich.
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for id in _expand(resources):
		add_child(_make_card(id))
	_layout()


## Eine Karte je Einheit, in fester Reihenfolge (damit die Hand nicht "springt").
func _expand(resources: Dictionary) -> Array:
	var out: Array = []
	for id in CatanPalette.RESOURCE_ORDER:
		for _i in int(resources.get(id, 0)):
			out.append(id)
	for id in resources:
		if not CatanPalette.RESOURCE_ORDER.has(id):
			for _i in int(resources[id]):
				out.append(id)
	return out


## Fächert die Karten im Bogen um die Bildmitte (Drehpunkt unten = Hand-Pivot).
func _layout() -> void:
	var cards := get_children()
	var n := cards.size()
	if n == 0:
		return
	# Direkt mit der Fenstergröße rechnen (size der Control kann beim Layout noch 0 sein).
	var win := get_viewport_rect().size
	var spread := deg_to_rad(minf(MAX_SPREAD_DEG, PER_CARD_DEG * float(n - 1)))
	var spacing := clampf((win.x * 0.5) / float(maxi(n - 1, 1)), MIN_SPACING, MAX_SPACING)
	var fan_w := spacing * float(n - 1)
	var center_x := win.x * 0.5                          # Fensterbreite / 2
	var base_y := win.y - CARD_SIZE.y - BOTTOM_MARGIN    # nahe Fensterunterkante
	for i in n:
		var card: Control = cards[i]
		card.size = CARD_SIZE
		card.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)   # Drehpunkt unten-mittig
		var t := 0.0 if n == 1 else float(i) / float(n - 1) - 0.5     # -0.5 .. 0.5
		card.rotation = t * spread
		card.position = Vector2(center_x + t * fan_w - CARD_SIZE.x * 0.5, base_y + absf(t) * ARC_DROP)


func _make_card(id: StringName) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = CatanPalette.resource_color(id)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3)
	sb.border_color = sb.bg_color.darkened(0.45)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 5
	card.add_theme_stylebox_override("panel", sb)

	var fg := Color.WHITE if _is_dark(id) else CatanPalette.INK_BLACK

	# Großes Symbol mittig.
	var icon := ResourceIcon.new()
	icon.resource_id = id
	icon.icon_color = fg
	icon.custom_minimum_size = Vector2(38, 38)
	icon.size = Vector2(38, 38)
	icon.position = (CARD_SIZE - Vector2(38, 38)) * 0.5
	card.add_child(icon)

	# Name oben-links + kleines Spiegel-Symbol unten-rechts (Spielkarten-Look).
	var name_label := Label.new()
	name_label.text = CatanPalette.resource_label(id)
	name_label.add_theme_color_override("font_color", fg)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.position = Vector2(6, 4)
	card.add_child(name_label)

	var corner := ResourceIcon.new()
	corner.resource_id = id
	corner.icon_color = fg
	corner.custom_minimum_size = Vector2(14, 14)
	corner.size = Vector2(14, 14)
	corner.position = CARD_SIZE - Vector2(20, 20)
	card.add_child(corner)

	return card


func _is_dark(id: StringName) -> bool:
	var c := CatanPalette.resource_color(id)
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b < 0.5
