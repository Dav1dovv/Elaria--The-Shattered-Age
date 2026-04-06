extends Node
class_name music_library

@onready var music : BlazeMusicManager = %MusicManager  # поправь путь если нужно

func _ready() -> void:
	music.tracks = {
		"MainMenu":{
			"day": [preload("uid://cmwm2pepooevf")],
			"night" :[preload("uid://cmwm2pepooevf")]
		}
		# Новая локация — просто копируй блок:
		# "Desert": {
		#     "day":   [preload("res://audio/music/desert_day.mp3")],
		#     "night": [preload("res://audio/music/desert_night.mp3")]
		# },
	}
