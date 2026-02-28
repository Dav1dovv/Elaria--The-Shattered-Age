## FuelItemData.gd
## Предмет с шкалой заполнения (например, канистра бензина).
## Вместо количества — уровень fill_level от 0.0 до 1.0.
## Не стакается; в инвентаре показывает прогресс-бар заполнения.

@icon("res://common/icons/helpcon2.png")
extends ItemData
class_name FuelItemData

signal fill_changed(new_level: float)
signal fully_filled

## Текущий уровень заполнения [0.0 … 1.0]
@export_range(0.0, 1.0, 0.01) var fill_level: float = 0.0:
	set(v):
		fill_level = clampf(v, 0.0, 1.0)
		emit_signal("fill_changed", fill_level)
		if is_full():
			emit_signal("fully_filled")

## Максимальное «количество единиц» топлива (например, 100 единиц = бак)
@export var max_fuel_units: float = 100.0

## Цвет шкалы заполнения в инвентаре
@export var bar_color: Color = Color(0.95, 0.55, 0.05)   # оранжевый

func _init() -> void:
	# Предмет не стакается — у каждой канистры свой уровень
	stackable = false
	max_count  = 1

## Добавить топливо (units — в тех же единицах, что max_fuel_units)
func add_fuel(units: float) -> float:
	var before  := fill_level
	fill_level  += units / max_fuel_units
	var consumed := (fill_level - before) * max_fuel_units
	return consumed          # сколько реально влезло

## Использовать топливо (вернёт false если пусто)
func consume_fuel(units: float) -> bool:
	if fill_level <= 0.0:
		return false
	fill_level -= units / max_fuel_units
	return true

## Полностью ли заполнен предмет?
func is_full() -> bool:
	return fill_level >= 1.0

## Пуст?
func is_empty() -> bool:
	return fill_level <= 0.0

## Текущее количество единиц топлива
func get_fuel_units() -> float:
	return fill_level * max_fuel_units

## Текст для тултипа (переопределяет базовый description)
func get_fill_text() -> String:
	return "%.0f / %.0f units  (%.0f%%)" % [get_fuel_units(), max_fuel_units, fill_level * 100.0]
