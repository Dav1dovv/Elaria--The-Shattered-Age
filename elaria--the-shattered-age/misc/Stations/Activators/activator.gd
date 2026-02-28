extends Node2D

## Название анимации активации в AnimationPlayer
@export var activation_animation: String = "activate"
## Сообщения подсказок
@export var need_item : ItemData
@onready var interaction: interaction_area = $interaction

var is_activated : bool = false

@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	interaction.interact = Callable(self, "open")
func open():
		if !is_activated and Global.inventory.has_total_item(need_item,40):
			$AnimationPlayer.play("Activate")
			Global.inventory.remove_from_total(need_item,39)
			interaction.queue_free()
			get_tree().get_first_node_in_group("World").activate_station()
