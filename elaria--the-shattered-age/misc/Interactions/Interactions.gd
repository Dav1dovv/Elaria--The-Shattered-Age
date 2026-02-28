extends Node2D

@onready var interaction: interaction_area = $Interaction


func _ready() -> void:
	interaction.interact = Callable(self, "back")

func back():
	Global.scene_manager.change_scene("World",true,Vector2.ZERO)
