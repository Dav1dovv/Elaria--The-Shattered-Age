extends Sprite2D

@onready var interaction: interaction_area = $interaction_area


func _ready() -> void:
	interaction.interact = Callable(self, "interact")

func interact():
	get_tree().call_group("Save","save_game")
	Global.scene_manager.fade()
