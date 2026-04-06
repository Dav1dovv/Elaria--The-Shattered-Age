extends Node2D

## Название анимации активации в AnimationPlayer
@export var activation_animation: String = "activate"
## Сообщения подсказок
@onready var interaction: interaction_area = $interaction
@onready var interacton_collision: CollisionShape2D = $interaction/CollisionShape2D

var is_activated : bool = false
var is_enabled : bool = false

@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	interaction.show_message = "stop"
	interaction.interact = Callable(self, "open")
func open():
		$AnimationPlayer.play("Activate")
		await $AnimationPlayer.animation_finished
		Global.scene_manager.change_scene("World",true,Vector2.ZERO)


func _on_timer_timeout() -> void:
	is_enabled = true
	interaction.show_message = "Back to ship"
