extends Entity
class_name Enemy

@export_range(1,5,1) var enemy_lvl : int = 1
@export var lvl_changeable : bool = false

func _init() -> void:
	add_to_group("Ennemy")
	if lvl_changeable:
		if Global.game_progress >= 60:
				if randf() > 0.4:
					enemy_lvl = 1
					scale = Vector2(1.5,1.5)
		elif Global.game_progress >= 30:
				if randf() > 0.4:
					enemy_lvl = 1
					scale = Vector2(2,2)
