extends Node
class_name SceneManager

const MAIN_MENU = "res://Assets/Scenes/Menu/main_menu.tscn"
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var message_label: Label = $CanvasLayer/ColorRect/Message

@export var messages: Array[String] = ["Mineral warriors is dangerous"," Tree's is best helpfule instrument", "forest's not so dangerous than thundra or desert"]

@export var scenes : Dictionary = {
	"Test_Scene" : "res://Assets/Locations/WorlRoot.tscn",
	"World" : "res://Assets/Scenes/Playable/world_root.tscn",
	"oktavia" : "res://Assets/Scenes/Playable/Planets/Oktavia.tscn"}

#func _ready() -> void:
	#Global.developer_console.register_command("change_scene",_cmd_change_scene,"chaging scene to X: change_scene")

#func _cmd_change_scene(args: Array) -> String:
	#if args.size() == 1 and args[0].is_valid_string():
		#var loc = args[0].to_string()
		#change_scene(loc,false,Vector2(0,0))
		#return "change scene to" + loc
	#return "Usage: location [value]"

func change_scene(scene : String, can_save : bool, player_position: Vector2):
	update_message()
	get_parent().current_location = scene
	if can_save:
		get_parent().save()
	# ← меняем музыку под новую локацию
	get_tree().call_group("MusicManager", "on_scene_changed", scene)
	Cursor.detection_mode(true)
	animation_player.play("Fade_In")
	await get_tree().create_timer(3).timeout
	update_message()
	get_tree().change_scene_to_file(scenes[scene])
	await get_tree().create_timer(4).timeout
	if player_position != Vector2.ZERO:
		var pl = get_tree().get_first_node_in_group("Player")
		if pl != null: pl.position = player_position
	await get_tree().create_timer(2).timeout
	animation_player.play("Fade_out")
	Cursor.detection_mode(false)

func change_to_main_menu():
	update_message()
	Cursor.detection_mode(true)
	get_tree().call_group("Save","save_game")
	animation_player.play("Fade_In")
	await get_tree().create_timer(3).timeout
	get_tree().change_scene_to_file(MAIN_MENU)
	animation_player.play("Fade_out")

func fade():
	update_message()
	animation_player.play("Fade_In")
	await get_tree().create_timer(3).timeout
	animation_player.play("Fade_out")

func update_message():
	randomize()
	message_label.text = messages.pick_random()
