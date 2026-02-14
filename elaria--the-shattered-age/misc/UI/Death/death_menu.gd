extends Control

var player

func _ready() -> void:
	player = get_parent().get_parent()
	visible = false
	

func death():
	$AnimationPlayer.play("Blur")
	visible = true
	$Panel.visible = true




func _on_main_menu_pressed() -> void:
	Global.scene_manager.change_to_main_menu()


func _on_revive_pressed() -> void:
	player.save_and_load.load_player(player)
	print(Global.current_location)
	Global.scene_manager.change_scene(Global.current_location,false,Vector2.ZERO)
	
