extends Node2D

const need_tool = preload("uid://xyck3q0gr12o")


@onready var interaction : interaction_area = $interaction_area
#@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var player = get_tree().get_first_node_in_group("Player")
var is_opened = false
var chest_lvl : int = 1
var need_key : bool = false
var need_count : int = 10

func _ready():
	randomize()
	need_count = randi_range(3,20)
	interaction.interact = Callable(self, "open")
	interaction.show_message = "X " + str(need_count)

func open():
		if !is_opened and Global.inventory.has_total_item(need_tool,need_count):
			$AnimationPlayer.play("Open")
			Global.inventory.remove_from_total(need_tool,need_count)
			is_opened = true
			$interaction_area.queue_free()
		else:
			$SFX.play()
			if need_tool != null:
				Global.hint(self,"you need " + need_tool.item_name)
			else:
				Global.hint(self,"this is bug")

func _on_timer_timeout() -> void:
	queue_free()
