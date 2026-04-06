extends Control


@onready var label: Label = $HBoxContainer/Label

var player

func _ready() -> void:
	if !player:
		player = get_tree().get_first_node_in_group("Player")
		if player == null:
			return
	return

func _process(delta: float) -> void:
	var fps = "FPS: " + str(Engine.get_frames_per_second()) + "/" + str(Engine.max_fps)
	if player:
		var player_info = "Player info: \n"+ "player_name: "+ Global.player_name + "\ngame-progress: " + str(Global.game_progress)
		label.text = fps + "\n" + str(Engine.get_physics_frames())+ "\n"  + player_info
	else:
		label.text = fps + "\n" + str(Engine.get_physics_frames()) + "\n Current location: " + Global.current_location + "\n " 
	if Input.is_action_just_pressed("ui_debug"):
		visible = !visible
		

func update():
		player = get_tree().get_first_node_in_group("Player")
		if player == null:
			return
	
