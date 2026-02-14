@icon("res://common/icons/helpcon3.png")
extends ItemData
class_name equip_data

@export_category("equip_data")
@export var lvl : int = 1
#@export_range(50,250) var durability : int = 50
@export_range(1,93,1) var Damage : int = 7
@export_range(10.0,100.0,0.1) var hit_distance : float = 10.0
@export_range(0.85,3,0.01) var Atk_speed : float = 1.0
@export var equiped_weapon_sprite : Texture
@export var projectile : PackedScene
@export var is_weapon : bool = true
@export var num_projectiles : int = 1
@export var spread_degrees : float = 0.0  ## Разброс в градусах (0 = точный, 20 = дробовик)
@export var projectile_speed : float = 400.0  ## Скорость снаряда (пикселей/сек)
#@export_enum("normal", "boomerang", "bomb") var projectile_type: String = "normal"
##Пиксели, до которых гарантированно попадание. Варьируйте per инструмент (например, для меча 30, для лука 50).
@export var accuracy_radius: float = 20.0
## Шанс промаха за каждый пиксель сверх радиуса (например, 0.1 для неточного оружия, 0.01 для точного).
@export var miss_chance_per_unit: float = 0.05  

@export_subgroup("critical hits")
## Радиус для критического удара (меньше accuracy_radius)
@export var critical_radius: float = 5.0  
## Шанс критического удара (20%)
@export_range(0.01,1) var critical_chance: float = 0.2  
## Множитель урона при критическом ударе
@export var critical_multiplier: float = 2.0  
@export_group("Attack Behavior")
## Если true, атака проигрывается один раз при нажатии LMB. Если false, анимация повторяется непрерывно пока кнопка нажата.
@export var one_shot_attack: bool = true

# Переопределение для оружия: улучшаем Damage, Atk_speed, durability
func apply_quality_multiplier(q: int) -> void:
	super.apply_quality_multiplier(q)  # Вызываем базовый (для description)
	Damage *= (1.0 + q * 0.5)  # Rare: +50%, Epic: +100%
	Atk_speed += q * 0.1  # +0.1 за уровень качества
	#durability += q * 10  # +10 durability
	print("Equip quality ", q, " applied to ", item_name, ": Damage=", Damage, ", Atk_speed=", Atk_speed)
