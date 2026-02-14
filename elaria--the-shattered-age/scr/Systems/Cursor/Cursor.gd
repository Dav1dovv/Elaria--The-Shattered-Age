extends Area2D

const MOUSE_Arrow = preload("res://Assets/Textures/UI/Cursors/Cursor1.png")

const MOUSE_Interact = preload("res://Assets/Textures/UI/Cursors/Cursor5.png")
const MOUSE_Shot = preload("res://Assets/Textures/UI/Cursors/Cursor2.png")
const MOUSE_Attack = preload("res://Assets/Textures/UI/Cursors/Cursor3.png")
const MOUSE_Gather = preload("res://Assets/Textures/UI/Cursors/Cursor4.png")

@export var help_label : Label
@onready var hint: Sprite2D = $Hint

func _init() -> void:
	set_collision_layer_value(1,false)
	set_collision_mask_value(1,false)
	set_collision_layer_value(9,true)
	set_collision_mask_value(8,true)


func _on_area_entered(area: interaction_area) -> void:
	if area.is_in_group("Harvestable"):
		change_curosr("gather")
	elif area.is_in_group("Ennemy"):
		change_curosr("fight")
	elif area.is_in_group("interaction"):
		change_curosr("interact")
		help_label.text = area.show_message

func _on_area_exited(area: interaction_area) -> void:
	help_label.text = ""
	hint.visible = false

func _process(delta: float) -> void:
	global_position = get_global_mouse_position()
	
func Help_hint(Help_Texture):
	hint.visible = true
	hint.texture = Help_Texture
	

func change_curosr(type: String):
	match type:
		"interact":
			Input.set_custom_mouse_cursor(MOUSE_Interact,Input.CURSOR_ARROW,Vector2(0,0))
			print("cursor change to interaction")
		"gather":
			Input.set_custom_mouse_cursor(MOUSE_Gather,Input.CURSOR_ARROW,Vector2(0,0))
			print("cursor change to gather")
		"fight":
			Input.set_custom_mouse_cursor(MOUSE_Attack,Input.CURSOR_ARROW,Vector2(0,0))
		"simple":
			Input.set_custom_mouse_cursor(MOUSE_Arrow,Input.CURSOR_ARROW,Vector2(0,0))

func detection_mode(mode : bool):
	$CollisionShape2D.disabled = mode
	if mode:
		change_curosr("simple")
