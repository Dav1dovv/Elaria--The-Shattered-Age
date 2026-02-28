extends Node
class_name music_library

@onready var music : BlazeMusicManager = %MusicManager  # поправь путь если нужно

func _ready() -> void:
	music.tracks = {
		"Frest": {
			"day":   [preload("uid://bys8500bb3pv4"), preload("uid://s7kinqfxw06f")],
			"night": [preload("uid://bys8500bb3pv4"), preload("uid://s7kinqfxw06f")]
			},
		"Land": {
			"day":   [preload("uid://7xj8q53gtp1p"),preload("uid://3n4yg6ifcr72")],
			"night": [preload("uid://7xj8q53gtp1p"),preload("uid://3n4yg6ifcr72")]
			},
		"EmeraldGrass": {
			"day":   [preload("uid://7xj8q53gtp1p"),preload("uid://3n4yg6ifcr72"),preload("uid://yehylhmsgj5u")],
			"night": [preload("uid://7xj8q53gtp1p"),preload("uid://3n4yg6ifcr72")]
			},
		"Shrimpy": {
			"day":   [preload("uid://6rghb1njitii"), preload("uid://yehylhmsgj5u")],
			"night":  [preload("uid://6rghb1njitii"), preload("uid://yehylhmsgj5u")]
			},
		"Forest": {
			"day":   [preload("uid://6rghb1njitii"), preload("uid://yehylhmsgj5u")],
			"night":  [preload("uid://6rghb1njitii"), preload("uid://yehylhmsgj5u")]
			},
		"MainMenu":{
			"day": [preload("uid://cw5b15ij4r7ub")],
			"night" :[preload("uid://cw5b15ij4r7ub")]
		}
		# Новая локация — просто копируй блок:
		# "Desert": {
		#     "day":   [preload("res://audio/music/desert_day.mp3")],
		#     "night": [preload("res://audio/music/desert_night.mp3")]
		# },
	}
