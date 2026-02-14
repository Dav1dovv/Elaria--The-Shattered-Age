extends AudioStreamPlayer
class_name BlazeMusicManager

# Все треки в одном месте.
# Ключ = имя сцены из SceneManager.scenes
# { "имя_сцены": { "day": [треки], "night": [треки] } }
var tracks : Dictionary = {}

var current_scene : String = "MainMenu"
var is_night      : bool   = false

func _init() -> void:
	connect("finished", _play_next)

func on_scene_changed(scene_name: String) -> void:
	print("trying to change music theme to : ", scene_name)
	if current_scene == scene_name:
		return
	current_scene = scene_name
	_play_next()

func on_phase_changed(night: bool) -> void:
	if is_night == night:
		return
	is_night = night
	_play_next()

func _play_next() -> void:
	stop()
	if not tracks.has(current_scene):
		return
	var pool : Array = tracks[current_scene].get("night" if is_night else "day", [])
	if pool.is_empty():
		return
	stream = pool.pick_random()
	play()
