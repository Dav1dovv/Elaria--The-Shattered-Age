# EntityConfig.gd
# Конфиг поведения существа — назначается через инспектор
extends Resource
class_name EntityConfig

# ─────────────────────────────────────────────
#  ТИП СУЩЕСТВА
# ─────────────────────────────────────────────
@export_group("🎭 Тип существа")

enum CreatureType {
	MELEE_ENEMY,      ## Бежит к игроку, бьёт в ближнем бою
	RANGED_ENEMY,     ## Держит дистанцию и стреляет
	KAMIKAZE,         ## Несётся к игроку и взрывается — урон всем вокруг
	RAM,              ## Разгоняется и таранит — сбивает с ног
	TOUCH_ATTACKER,   ## Наносит урон при любом касании игрока
	FLEEING,          ## Убегает от игрока (животное)
	PEACEFUL,         ## Игнорирует игрока, гуляет
	MERCHANT,         ## Мирный + диалог/торговля при взаимодействии
}

@export var creature_type: CreatureType = CreatureType.MELEE_ENEMY

# ─────────────────────────────────────────────
#  ОБНАРУЖЕНИЕ
# ─────────────────────────────────────────────
@export_group("👁 Обнаружение")

## Радиус, в котором существо замечает игрока
@export_range(30, 900, 5) var detection_range: float = 200.0

## Дистанция для ближней атаки / личного пространства (Fleeing)
@export_range(0, 200, 5) var close_range: float = 60.0

## Оптимальная дистанция для стрельбы (только RANGED)
@export_range(80, 600, 10) var optimal_shoot_range: float = 250.0

# ─────────────────────────────────────────────
#  ДВИЖЕНИЕ
# ─────────────────────────────────────────────
@export_group("🏃 Движение")

## Множитель скорости во время преследования
@export_range(1.0, 20.0, 0.5) var chase_speed_mult: float = 10.0

## Множитель скорости во время блуждания
@export_range(1.0, 10.0, 0.5) var wander_speed_mult: float = 5.0

## Множитель скорости при побеге (только FLEEING)
@export_range(1.0, 20.0, 0.5) var flee_speed_mult: float = 12.0

## Случайное смещение при подходе к игроку (манёвры)
@export_range(0, 100, 5) var approach_offset: float = 30.0

## Интервал смены смещения (секунды)
@export_range(0.5, 5.0, 0.1) var offset_change_interval: float = 1.5

## Интервал между состояниями блуждания
@export_range(1.0, 10.0, 0.5) var wander_interval: float = 3.0

## Время успокоения после побега (только FLEEING)
@export_range(1.0, 15.0, 0.5) var calm_down_time: float = 4.0

# ─────────────────────────────────────────────
#  БОЙ
# ─────────────────────────────────────────────
@export_group("⚔️ Бой")

## Скорость поворота HitBox к цели (рад/сек)
@export var rotation_speed: float = 5.0

## Интервал между атаками в ближнем бою (секунды)
@export_range(0.1, 5.0, 0.1) var attack_cooldown: float = 1.0

## Перезарядка выстрела (только RANGED, секунды)
@export var shoot_cooldown: float = 1.5

## Сцена снаряда (только RANGED)
@export var projectile_scene: PackedScene

# ─────────────────────────────────────────────
#  КАМИКАДЗЕ
# ─────────────────────────────────────────────
@export_group("💣 Камикадзе")

## Дистанция срабатывания взрыва
@export_range(20, 300, 5) var explosion_trigger_range: float = 60.0

## Радиус взрыва (урон всем — игрокам, врагам, окружению)
@export_range(50, 500, 10) var explosion_radius: float = 150.0

## Урон взрыва
@export var explosion_damage: float = 80.0

## Время задержки перед взрывом (секунды)
@export_range(0.0, 3.0, 0.1) var explosion_fuse_time: float = 0.5

## Сцена эффекта взрыва (VFX)
@export var explosion_vfx_scene: PackedScene

## Наносить урон и другим врагам?
@export var explosion_hits_enemies: bool = true

# ─────────────────────────────────────────────
#  ТАРАН
# ─────────────────────────────────────────────
@export_group("🚀 Таран")

## Дистанция начала разгона
@export_range(50, 500, 10) var ram_charge_range: float = 250.0

## Множитель скорости во время тарана
@export_range(2.0, 30.0, 0.5) var ram_speed_mult: float = 18.0

## Время разгона перед таранным ударом (секунды)
@export_range(0.1, 2.0, 0.1) var ram_charge_time: float = 0.6

## Урон тарана
@export var ram_damage: float = 50.0

## Кулдаун тарана (секунды)
@export_range(1.0, 10.0, 0.5) var ram_cooldown: float = 3.0

## Откат врага после тарана (секунды)
@export_range(0.1, 2.0, 0.1) var ram_recovery_time: float = 0.8

# ─────────────────────────────────────────────
#  КОНТАКТНЫЙ АТАКУЮЩИЙ
# ─────────────────────────────────────────────
@export_group("👆 Контактный атакующий")

## Урон при каждом касании игрока
@export var touch_damage: float = 10.0

## Интервал между тиками урона при касании (секунды)
@export_range(0.1, 3.0, 0.1) var touch_damage_interval: float = 0.5

## Замедляет игрока при касании?
@export var touch_slows_player: bool = false

## Множитель замедления (0.1 = 90% замедления)
@export_range(0.1, 0.9, 0.05) var touch_slow_multiplier: float = 0.5

# ─────────────────────────────────────────────
#  АНИМАЦИИ
# ─────────────────────────────────────────────
@export_group("🎬 Анимации")

@export var anim_idle: String = "Idle"
@export var anim_walk: String = "Walk"
@export var anim_attack: String = "Attack"
@export var anim_shoot: String = "Shoot"
@export var anim_aim: String = "Aim"
@export var anim_death: String = "Death"
@export var anim_charge: String = "Charge"     ## для тарана
@export var anim_explode: String = "Explode"   ## для камикадзе

# ─────────────────────────────────────────────
#  ЗВУКИ
# ─────────────────────────────────────────────
@export_group("🔊 Звуки")

@export var sound_enabled: bool = false

@export_subgroup("🎵 Idle")
@export var idle_sounds: Array[AudioStream] = []
@export_range(2.0, 60.0, 0.5) var idle_sound_min: float = 5.0
@export_range(2.0, 120.0, 0.5) var idle_sound_max: float = 15.0

@export_subgroup("👁 Aggro")
@export var aggro_sounds: Array[AudioStream] = []

@export_subgroup("⚔️ Атака")
@export var attack_sounds: Array[AudioStream] = []

@export_subgroup("💥 Урон")
@export var hurt_sounds: Array[AudioStream] = []

@export_subgroup("😱 Испуг")
@export var scared_sounds: Array[AudioStream] = []

@export_subgroup("💣 Взрыв")
@export var explosion_sounds: Array[AudioStream] = []

@export_subgroup("🚀 Таран")
@export var ram_charge_sounds: Array[AudioStream] = []
@export var ram_impact_sounds: Array[AudioStream] = []

@export_subgroup("💀 Смерть")
@export var death_sounds: Array[AudioStream] = []

# ─────────────────────────────────────────────
#  СМЕРТЬ / ДРОП
# ─────────────────────────────────────────────
@export_group("💀 Смерть")

@export_range(0.0, 1.0, 0.05) var drop_chance: float = 0.5
@export_range(1.0, 10.0, 0.5) var death_linger_time: float = 4.0

# ─────────────────────────────────────────────
#  ДИАЛОГ / ТОРГОВЛЯ
# ─────────────────────────────────────────────
@export_group("💬 Диалог / Торговля")

@export var merchant_data: Resource
@export var dialogues: Array[String] = []
