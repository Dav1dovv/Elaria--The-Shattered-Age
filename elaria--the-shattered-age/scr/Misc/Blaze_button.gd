extends Button


func _on_mouse_entered() -> void:
	$Hover.play()

func _on_pressed() -> void:
	if disabled:
		$Decline.play()
	else:
		$Accept.play()
