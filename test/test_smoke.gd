class_name Test
extends GutTest
## Smoke-Test: prüft nur, dass GUT headless läuft.


func test_truth() -> void:
	assert_eq(1 + 2, 2, "Mathematik funktioniert")
