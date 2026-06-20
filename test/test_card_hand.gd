extends GutTest
## Prüft die Handkarten-Komponente: eine Karte je Ressourceneinheit, korrekter Bau.

func test_expand_one_card_per_unit() -> void:
	var hand := CardHand.new()
	add_child_autofree(hand)
	var ids := hand._expand({&"wood": 3, &"ore": 1})
	assert_eq(ids.size(), 4)
	assert_eq(ids.filter(func(x): return x == &"wood").size(), 3)


func test_set_cards_creates_card_nodes() -> void:
	var hand := CardHand.new()
	add_child_autofree(hand)
	hand.set_cards({&"grain": 2})
	assert_eq(hand.get_child_count(), 2, "zwei Getreide → zwei Karten")


func test_cards_centered_on_window_width() -> void:
	var hand := CardHand.new()
	add_child_autofree(hand)
	await get_tree().process_frame
	hand.set_cards({&"wood": 3})   # 3 Karten → mittlere (Index 1) muss zentriert sein
	var win := hand.get_viewport_rect().size
	var mid: Control = hand.get_child(1)
	var mid_center_x := mid.position.x + CardHand.CARD_SIZE.x * 0.5
	assert_almost_eq(mid_center_x, win.x * 0.5, 1.0)


func test_rebuild_replaces_not_accumulates() -> void:
	# Reroll-Szenario: neue Ressourcen → Hand neu bauen. Alte Karten dürfen nicht
	# mitgezählt werden (sonst verschieben sich die Karten beim Würfeln).
	var hand := CardHand.new()
	add_child_autofree(hand)
	await get_tree().process_frame
	hand.set_cards({&"wood": 2})
	hand.set_cards({&"ore": 3})
	assert_eq(hand.get_child_count(), 3, "alte Karten müssen sofort entfernt sein")
	var win := hand.get_viewport_rect().size
	var mid: Control = hand.get_child(1)
	assert_almost_eq(mid.position.x + CardHand.CARD_SIZE.x * 0.5, win.x * 0.5, 1.0)
