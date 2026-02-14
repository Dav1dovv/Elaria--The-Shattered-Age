extends Node
class_name  weather

@export var active: bool = true

# ===================== ЭФФЕКТЫ (просто перетащи сцены) =====================
@export var rain_effect: PackedScene
@export var heavy_rain_effect: PackedScene
@export var snow_effect: PackedScene
@export var fog_effect: PackedScene
@export var sandstorm_effect: PackedScene
@export var clear_sky_effect: PackedScene   # например, звёздное небо ночью

# ===================== ШАНСЫ ПО СЕЗОНАМ (просто ползунки) =====================
@export_category("Шансы погоды (%) — просто тяни ползунки")
@export_range(0,100) var rain_chance_yanuaris:   int = 30
@export_range(0,100) var rain_chance_kardus:     int = 80
@export_range(0,100) var rain_chance_tirena:     int = 10
@export_range(0,100) var rain_chance_vallis:     int = 5
@export_range(0,100) var rain_chance_lira:       int = 60
@export_range(0,100) var rain_chance_eikhon:     int = 15
@export_range(0,100) var rain_chance_verda:      int = 40
@export_range(0,100) var rain_chance_morva:      int = 90   # дождь + фиолетовый туман?

@export_range(0,100) var snow_chance_cold_seasons: int = 70   # только в холодных (Eikhon, Verda, Morva)
@export_range(0,100) var fog_chance:               int = 25
@export_range(0,100) var sandstorm_chance_hot:     int = 40   # только в жарких (Vallis, Lira?)

# ===================== НАСТРОЙКИ СМЕНЫ =====================
@export_range(5, 40) var min_minutes_between_changes: float = 12
@export_range(10, 60) var max_minutes_between_changes: float = 25

# ===================== ВНУТРЕННЕЕ =====================
var current_effect: Node = null
var timer := Timer.new()
var day_night = null

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	add_child(timer)
	timer.one_shot = true
	timer.timeout.connect(_change_weather)
	
	day_night = get_tree().get_first_node_in_group("DayNight")
	
	if active:
		_change_weather()           # сразу при входе в локацию
		_start_timer()

func _start_timer() -> void:
	var next = randf_range(min_minutes_between_changes, max_minutes_between_changes) * 60
	timer.start(next)

func _change_weather() -> void:
	_remove_current_effect()
	
	var season = _get_season_name()
	var is_night = _is_night()
	var roll = randi_range(1, 100)
	
	# --- СНЕГ только в холодных сезонах ---
	if season in ["Eikhon", "Verda", "Morva"] and roll <= snow_chance_cold_seasons:
		_spawn_effect(snow_effect)
		_start_timer()
		return
	
	# --- Песчаная буря в жарких ---
	if season in ["Vallis", "Lira"] and roll <= sandstorm_chance_hot:
		_spawn_effect(sandstorm_effect)
		_start_timer()
		return
	
	# --- Дождь по сезонам ---
	var rain_chance = _get_rain_chance_for_season(season)
	if roll <= rain_chance:
		if roll <= rain_chance / 3:  # сильный дождь редко
			_spawn_effect(heavy_rain_effect)
		else:
			_spawn_effect(rain_effect)
		_start_timer()
		return
	
	# --- Туман ---
	if roll <= fog_chance:
		_spawn_effect(fog_effect)
		_start_timer()
		return
	
	# --- Ясно (можно звёздное небо ночью) ---
	_spawn_effect(clear_sky_effect if is_night else null)
	_start_timer()

func _get_rain_chance_for_season(s: String) -> int:
	return get("rain_chance_" + s.to_lower()) if has_method("get") else 20

func _get_season_name() -> String:
	if day_night and "current_season" in day_night:
		return day_night.Season.keys()[day_night.current_season]
	return "Yanuaris"

func _is_night() -> bool:
	if day_night and "current_phase" in day_night:
		return day_night.current_phase == day_night.Phase.NIGHT
	return false

func _spawn_effect(scene: PackedScene) -> void:
	if not scene: return
	current_effect = scene.instantiate()
	get_child(0).add_child(current_effect)

func _remove_current_effect() -> void:
	if current_effect and is_instance_valid(current_effect):
		current_effect.queue_free()
	current_effect = null

# Ручная смена (например, по триггеру)
func force_weather(type: String) -> void:
	_remove_current_effect()
	match type.to_lower():
		"rain": _spawn_effect(rain_effect)
		"heavy_rain": _spawn_effect(heavy_rain_effect)
		"snow": _spawn_effect(snow_effect)
		"fog": _spawn_effect(fog_effect)
		"sandstorm": _spawn_effect(sandstorm_effect)
		"clear": pass
