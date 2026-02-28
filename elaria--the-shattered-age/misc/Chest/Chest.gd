extends Node2D

@export var need_tool : ItemData

@onready var interaction : interaction_area = $interaction_area
#@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var player = get_tree().get_first_node_in_group("Player")
var is_opened = false
var chest_lvl : int = 1
var need_key : bool = false
var need : ItemData
var need_count : int = 10

func _ready():
	randomize()
	need_count = randi_range(3,20)
	interaction.interact = Callable(self, "open")
	interaction.show_message = "X " + str(need_count)

func open():
	if need_key:
		if !is_opened and need != null and Global.inventory.has_total_item(need,need_count):
			$AnimationPlayer.play("Open")
			Global.inventory.remove_from_total(need,need_count-1)
			is_opened = true
			$interaction_area.queue_free()
		elif !is_opened and need == null:
			$AnimationPlayer.play("Open")
			is_opened = true
			$interaction_area.queue_free()
		else:
			$SFX.play()
			if need != null:
				Global.hint(self,"you need " + need.item_name)
			else:
				Global.hint(self,"this is bug")
	else:
			$AnimationPlayer.play("Open")
			is_opened = true

func _on_timer_timeout() -> void:
	queue_free()
