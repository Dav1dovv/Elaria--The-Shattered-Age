extends AnimatedSprite2D

@onready var interaction: interaction_area = $Interaction

func _ready() -> void:
	interaction.interact = Callable(self, "save")
	play("Camp_on")
	$GPUParticles2D.emitting = true


func save():
	get_tree().paused = true
	Global.scene_manager.fade()
	get_tree().get_first_node_in_group("Player").heal(15)
	#get_tree().get_nodes_in_group("")
	get_tree().call_group("Ennemy","_kill")
	Global.day_night.next_phase()
	get_tree().paused = false
	play("Camp_off")
	interaction.queue_free()
