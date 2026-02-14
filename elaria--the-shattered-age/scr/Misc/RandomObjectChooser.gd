extends Node2D

func _ready() -> void:
	#var generator = get_tree().get_first_node_in_group("Generator")
	#var game_manager = get_tree().get_first_node_in_group("World")
	#var location_seed = game_manager.get_or_create_location_seed(generator.location_id)
	#seed(location_seed)
	var r_child = randi() % get_child_count()
	for i in get_child_count():
		
		if i == r_child:
			get_child(r_child).visible = true
		else:
			get_child(i).queue_free()
