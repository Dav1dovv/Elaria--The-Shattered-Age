@tool
extends AudioStreamPlayer
class_name Blaze_musicPlayer

func _init() -> void:
	connect("finished",_music_finished)

func _music_finished():
	play()
