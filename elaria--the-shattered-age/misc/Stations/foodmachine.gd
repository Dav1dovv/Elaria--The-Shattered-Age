extends Sprite2D

@onready var interaction: interaction_area = $interaction_area
const WAYFINDER = preload("uid://xyck3q0gr12o")

func _ready() -> void:
	interaction.interact = Callable(self,"use")

func use():
	if Global.inventory.has_total_item(WAYFINDER,5):
		$AudioStreamPlayer2D.play()
		$AnimationPlayer.play("use")
		Global.inventory.remove_from_total(WAYFINDER,5)
		await $AnimationPlayer.animation_finished
		$Drop_items._drop_items()
