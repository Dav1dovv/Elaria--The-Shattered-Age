# SpawnConfig.gd
extends Resource
class_name CreatureConfig

@export var creature_scene: PackedScene
@export_range(0.0, 10.0) var spawn_weight: float = 1.0
@export_enum("Day", "Night", "Both") var spawn_phase: String = "Both"

@export_group("Variations")
@export var variations: Array[PackedScene] = []  ## Рандомные варианты сцены

func get_random_scene() -> PackedScene:
	if variations.is_empty():
		return creature_scene
	var all_scenes := [creature_scene] + variations
	return all_scenes[randi() % all_scenes.size()]
