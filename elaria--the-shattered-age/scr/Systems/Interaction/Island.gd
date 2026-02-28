extends Area2D
class_name Island

@export_multiline var show_message : String = "interact"
@export var icon_help : Texture2D
var is_in_zone = false
var player
var interact:Callable = func():
	pass

func _init() -> void:
	set_collision_layer_value(1,false)
	set_collision_mask_value(1,false)
	set_collision_layer_value(12,true)
	set_collision_mask_value(13,true)
	add_to_group("interaction")
	connect("area_entered",_on_area_entered)
	connect("area_exited",_on_area_exited)

func _input(event: InputEvent) -> void:
	if is_in_zone:
		if Input.is_action_just_released("ui_accept"):
				interact.call()
	

func _on_area_entered(area: Area2D) -> void:
	print("mouse_enetered")
	#Input.set_custom_mouse_cursor(Global.MOUSE_Interact,Input.CURSOR_ARROW,Vector2(0,0))
	Cursor.Help_hint(icon_help)
	is_in_zone = true


func _on_area_exited(area: Area2D) -> void:
	print("mouse_exited")
	Input.set_custom_mouse_cursor(Global.MOUSE_Arrow,Input.CURSOR_ARROW,Vector2(0,0))
	is_in_zone = false
	Cursor.Help_hint(null)
	
