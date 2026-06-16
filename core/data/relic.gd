class_name Relic
extends Resource
## Ein Relikt/Modifikator, der während eines Runs die Regeln verändert
## (data-driven, als .tres editierbar).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D


## Wendet den Effekt des Relikts auf den Spielzustand an.
## (Parameter ist das GameState-Autoload — bewusst untypisiert, da Autoload-Name kein class_name ist.)
func apply(state) -> void:
	# TODO: Regeländerung umsetzen (z.B. Ausbeute-Bonus)
	pass
