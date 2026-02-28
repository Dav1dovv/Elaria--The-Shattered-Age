extends Area2D
class_name IslandInteraction

@export var location_ID : String


func _interact():
	print("wo")
	Global.scene_manager.change_scene(location_ID,true,Vector2.ZERO)
