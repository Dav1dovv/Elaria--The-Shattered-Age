extends Resource
class_name WeatherEntry

@export var weather_name: String = "rain"
@export_range(0, 100) var base_chance: float = 20.0

@export var night_bonus: float = 0.0
@export var full_moon_bonus: float = 0.0
@export var morva_bonus: float = 0.0

@export var only_at_day: bool = false
@export var only_at_night: bool = false
