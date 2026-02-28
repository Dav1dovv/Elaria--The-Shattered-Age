@icon("res://common/icons/helpcon3.png")
extends ItemData
class_name equip_data

@export_category("equip_data")
@export var lvl : int = 1
@export_range(10, 500, 1) var max_durability: int = 100
var durability: int = -1  # -1 = не инициализирована, установится при первом использовании
@export_range(1,93,1) var Damage : int = 7
@export_range(10.0,100.0,0.1) var hit_distance : float = 10.0
@export_range(0.85,3,0.01) var Atk_speed : float = 1.0
@export var equiped_weapon_sprite : Texture
@export var projectile : PackedScene
@export var is_weapon : bool = true
@export var num_projectiles : int = 1
@export var spread_degrees : float = 0.0  ## Разброс в градусах (0 = точный, 20 = дробовик)
@export var projectile_speed : float = 400.0  ## Скорость снаряда (пикселей/сек)
##Пиксели, до которых гарантированно попадание.
@export var accuracy_radius: float = 20.0
## Шанс промаха за каждый пиксель сверх радиуса
@export var miss_chance_per_unit: float = 0.05  

@export_subgroup("critical hits")
## Радиус для критического удара (меньше accuracy_radius)
@export var critical_radius: float = 5.0  
## Шанс критического удара (20%)
@export_range(0.01,1) var critical_chance: float = 0.2  
## Множитель урона при критическом ударе
@export var critical_multiplier: float = 2.0  
@export_group("Attack Behavior")
## Если true, атака проигрывается один раз при нажатии LMB.
@export var one_shot_attack: bool = true

## Сигнал: прочность изменилась (для обновления UI)
signal durability_changed(current: int, maximum: int)
## Сигнал: оружие сломано
signal weapon_broken

func get_durability() -> int:
	if durability < 0:
		durability = max_durability
	return durability

func reduce_durability(amount: int = 1) -> void:
	if durability < 0:
		durability = max_durability
	durability = max(0, durability - amount)
	emit_signal("durability_changed", durability, max_durability)
	if durability <= 0:
		emit_signal("weapon_broken")

func is_broken() -> bool:
	return get_durability() <= 0

func repair(amount: int = -1) -> void:
	if amount < 0:
		durability = max_durability
	else:
		durability = min(max_durability, get_durability() + amount)
	emit_signal("durability_changed", durability, max_durability)

func get_durability_ratio() -> float:
	return float(get_durability()) / float(max_durability)

# Переопределение для оружия: улучшаем Damage, Atk_speed, durability
func apply_quality_multiplier(q: int) -> void:
	super.apply_quality_multiplier(q)
	Damage = int(Damage * (1.0 + q * 0.5))   # Rare: +50%, Epic: +100%
	Atk_speed += q * 0.1
	max_durability += q * 25   # +25 прочности за уровень качества
	if durability > 0:
		durability = min(durability, max_durability)
	print("Equip quality ", q, " applied to ", item_name, ": Damage=", Damage, ", Atk_speed=", Atk_speed, ", max_durability=", max_durability)
