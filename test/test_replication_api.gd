extends GutTest
## Sichert die SceneReplicationConfig-API ab, die game_board._add_character_sync()
## für die Figuren-Bewegungsreplikation nutzt. Diese Pfade laufen offline nicht,
## daher hier ein Laufzeit-Check, damit falsche Enum-/Methodennamen früh auffallen.

func test_scene_replication_config_builds() -> void:
	var cfg := SceneReplicationConfig.new()
	for prop in [NodePath(".:position"), NodePath(".:rotation")]:
		cfg.add_property(prop)
		cfg.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	assert_eq(cfg.get_properties().size(), 2)


func test_multiplayer_synchronizer_accepts_config() -> void:
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:position"))
	var sync := MultiplayerSynchronizer.new()
	sync.replication_config = cfg
	sync.set_multiplayer_authority(1)
	assert_eq(sync.get_multiplayer_authority(), 1)
	sync.free()
