extends Node
class_name BlazeMusicManager

# Все треки в одном месте.
# Ключ = имя сцены из SceneManager.scenes
# { "имя_сцены": { "day": [треки], "night": [треки] } }
var tracks : Dictionary = {}

var current_scene : String = "MainMenu"
var is_night      : bool   = false

## Длительность кроссфейда в секундах
@export var fade_duration : float = 1.5

## Начальная сцена при запуске игры (должна совпадать с ключом в tracks)
@export var initial_scene : String = "MainMenu"

## Начинать ли с ночной музыки
@export var initial_is_night : bool = false

# Два плеера для кроссфейда
var _player_a : AudioStreamPlayer
var _player_b : AudioStreamPlayer
var _active   : AudioStreamPlayer  # тот, что сейчас играет
var _inactive : AudioStreamPlayer  # тот, куда переключаемся

var _tween : Tween = null

func _ready() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	add_child(_player_a)
	add_child(_player_b)

	_player_a.volume_db = linear_to_db(1.0)
	_player_b.volume_db = linear_to_db(0.0)

	_active   = _player_a
	_inactive = _player_b

	_player_a.connect("finished", _on_track_finished)
	_player_b.connect("finished", _on_track_finished)

	# Запускаем начальную музыку при старте
	current_scene = initial_scene
	is_night      = initial_is_night
	var pool : Array = _get_pool()
	if not pool.is_empty():
		_active.stream = pool.pick_random()
		_active.play()

func on_scene_changed(scene_name: String) -> void:
	print("trying to change music theme to : ", scene_name)
	if current_scene == scene_name:
		return
	current_scene = scene_name
	_crossfade_to_next()

func on_phase_changed(night: bool) -> void:
	if is_night == night:
		return
	is_night = night
	_crossfade_to_next()

func _on_track_finished() -> void:
	# Когда трек закончился — просто ставим следующий без кроссфейда
	var pool : Array = _get_pool()
	if pool.is_empty():
		return
	_active.stream = pool.pick_random()
	_active.play()

func _crossfade_to_next() -> void:
	var pool : Array = _get_pool()
	if pool.is_empty():
		_fade_out_active()
		return

	# Готовим неактивный плеер
	_inactive.stream = pool.pick_random()
	_inactive.volume_db = linear_to_db(0.0)
	_inactive.play()

	# Запускаем tween
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_active,   "volume_db", linear_to_db(0.0), fade_duration)
	_tween.tween_property(_inactive, "volume_db", linear_to_db(1.0), fade_duration)

	await _tween.finished

	_active.stop()

	# Меняем ролями
	var tmp  = _active
	_active   = _inactive
	_inactive = tmp

func _fade_out_active() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_active, "volume_db", linear_to_db(0.0), fade_duration)
	await _tween.finished
	_active.stop()

func _get_pool() -> Array:
	if not tracks.has(current_scene):
		return []
	return tracks[current_scene].get("night" if is_night else "day", [])
