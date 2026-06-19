class_name ResourceChip
extends RefCounted
## Baut einen farbcodierten "Chip" für eine Ressource (Icon + Menge).
## Es gibt keine Icon-Texturen im Projekt, daher zeichnet ResourceIcon eine
## kleine Silhouette pro Ressource prozedural statt ein Bild zu laden.
## Wird von HUD, BuildMenu, RoundPlanningPanel und BuildingPanel gemeinsam genutzt.

const CHIP_STYLE := preload("res://presentation/ui/theme/styles/chip_resource.tres")


static func build(id: StringName, amount: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", CHIP_STYLE)
	chip.self_modulate = CatanPalette.resource_color(id)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.tooltip_text = CatanPalette.resource_label(id)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)

	var font_color := Color.WHITE if _is_dark(id) else CatanPalette.INK_BLACK

	var icon := ResourceIcon.new()
	icon.resource_id = id
	icon.icon_color = font_color
	row.add_child(icon)

	var amount_label := Label.new()
	amount_label.name = "AmountLabel"
	amount_label.text = str(amount)
	amount_label.add_theme_color_override("font_color", font_color)
	amount_label.add_theme_font_size_override("font_size", 14)
	row.add_child(amount_label)

	return chip


## Baut eine Zeile aus mehreren Chips für ein Kosten-/Rezept-Dictionary.
static func build_row(goods: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if goods.is_empty():
		var dash := Label.new()
		dash.text = "–"
		row.add_child(dash)
		return row
	for id in CatanPalette.RESOURCE_ORDER:
		if goods.has(id):
			row.add_child(build(id, int(goods[id])))
	for id in goods:
		if not CatanPalette.RESOURCE_ORDER.has(id):
			row.add_child(build(id, int(goods[id])))
	return row


static func update_amount(chip: PanelContainer, amount: int) -> void:
	var amount_label : Label = chip.find_child("AmountLabel", true, false)
	if amount_label != null:
		amount_label.text = str(amount)


static func _is_dark(id: StringName) -> bool:
	var c := CatanPalette.resource_color(id)
	var luminance := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	return luminance < 0.5
