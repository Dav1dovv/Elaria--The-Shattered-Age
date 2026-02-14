extends Resource
class_name EntityConfig

# ─────────────────────────────────────────────
#  ТЕМА: тип существа — определяет базовое поведение
# ─────────────────────────────────────────────
@export_group("🎭 Тип существа")

enum CreatureType {
	MELEE_ENEMY,     ## Бежит к игроку, бьёт в ближнем бою
	RANGED_ENEMY,    ## Держит дистанцию и стреляет
	FLEEING,         ## Убегает от игрока (животное)
	PEACEFUL,        ## Игнорирует игрока, гуляет
	MERCHANT,        ## Мирный + диалог/торговля при взаимодействии
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

## Множитель скорости во время преследования (x Entity_stats.move_speed)
@export_range(1.0, 20.0, 0.5) var chase_speed_mult: float = 10.0

## Множитель скорости во время блуждания
@export_range(1.0, 10.0, 0.5) var wander_speed_mult: float = 5.0

## Множитель скорости при побеге (только FLEEING)
@export_range(1.0, 20.0, 0.5) var flee_speed_mult: float = 12.0

## Случайное смещение при подходе к игроку (манёвры)
@export_range(0, 100, 5) var approach_offset: float = 30.0

## Интервал смены смещения (секунды)
@export_range(0.5, 5.0, 0.1) var offset_change_interval: float = 1.5

## Интервал между состояниями блуждания (движение ↔ стоп)
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
#  АНИМАЦИИ
# ─────────────────────────────────────────────
@export_group("🎬 Анимации")

## Имена анимаций — переопредели если у твоей модели другие названия
@export var anim_idle: String = "Idle"
@export var anim_walk: String = "Walk"
@export var anim_attack: String = "Attack"
@export var anim_shoot: String = "Shoot"
@export var anim_aim: String = "Aim"
@export var anim_death: String = "Death"

# ─────────────────────────────────────────────
#  ЗВУКИ
# ─────────────────────────────────────────────
@export_group("🔊 Звуки")

## Включить/выключить всю звуковую систему
@export var sound_enabled: bool = false

@export_subgroup("🎵 Idle — случайные звуки в покое")
## Звуки когда существо гуляет / стоит
@export var idle_sounds: Array[AudioStream] = []
## Минимальный интервал между idle-звуками (сек)
@export_range(2.0, 60.0, 0.5) var idle_sound_min: float = 5.0
## Максимальный интервал между idle-звуками (сек)
@export_range(2.0, 120.0, 0.5) var idle_sound_max: float = 15.0

@export_subgroup("👁 Aggro — замечает игрока")
## Звук когда существо обнаружило игрока
@export var aggro_sounds: Array[AudioStream] = []

@export_subgroup("⚔️ Атака")
## Звук при каждой атаке / выстреле
@export var attack_sounds: Array[AudioStream] = []

@export_subgroup("💥 Получение урона")
## Звук при получении урона
@export var hurt_sounds: Array[AudioStream] = []

@export_subgroup("😱 Испуг / побег (FLEEING)")
## Звук когда существо пугается
@export var scared_sounds: Array[AudioStream] = []

@export_subgroup("💀 Смерть")
## Звук при смерти
@export var death_sounds: Array[AudioStream] = []

# ─────────────────────────────────────────────
#  СМЕРТЬ / ДРОП
# ─────────────────────────────────────────────
@export_group("💀 Смерть")

## Шанс выпадения лута (0.0 – 1.0)
@export_range(0.0, 1.0, 0.05) var drop_chance: float = 0.5

## Время до удаления объекта после смерти (секунды)
@export_range(1.0, 10.0, 0.5) var death_linger_time: float = 4.0

# ─────────────────────────────────────────────
#  ДИАЛОГ / ТОРГОВЛЯ (для PEACEFUL / MERCHANT)
# ─────────────────────────────────────────────
@export_group("💬 Диалог / Торговля")

## Данные торговца (только MERCHANT)
@export var merchant_data: Resource   # MerchantData

## Реплики при взаимодействии
@export var dialogues: Array[String] = []
