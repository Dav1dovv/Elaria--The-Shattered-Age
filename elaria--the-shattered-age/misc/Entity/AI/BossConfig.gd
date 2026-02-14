## BossConfig.gd
## Все настройки босса — в одном ресурсе.
## Создай .tres файл и назначь в инспекторе BossAI.

extends Resource
class_name BossConfig

# ─────────────────────────────────────────────
#  ФАЗЫ
# ─────────────────────────────────────────────
@export_group("⚡ Фазы")

## Количество фаз (1–3). Каждая фаза активируется при пороге HP
@export_range(1, 3, 1) var phase_count: int = 2

## HP% для входа во 2-ю фазу (0.0–1.0, например 0.6 = при 60% HP)
@export_range(0.0, 1.0, 0.05) var phase2_threshold: float = 0.6

## HP% для входа в 3-ю фазу
@export_range(0.0, 1.0, 0.05) var phase3_threshold: float = 0.3

## Воспроизвести анимацию при смене фазы
@export var phase_transition_anim: String = "PhaseTransition"

## Краткая неуязвимость во время перехода фазы (сек)
@export var phase_transition_duration: float = 1.2

# ─────────────────────────────────────────────
#  ОБНАРУЖЕНИЕ
# ─────────────────────────────────────────────
@export_group("👁 Обнаружение")

@export_range(100, 1500, 10) var detection_range: float = 600.0
@export_range(10, 250, 5)   var melee_range: float = 80.0

# ─────────────────────────────────────────────
#  ДВИЖЕНИЕ
# ─────────────────────────────────────────────
@export_group("🏃 Движение")

@export_range(1.0, 20.0, 0.5) var chase_speed_mult: float = 8.0

## Множитель скорости в фазе 2
@export_range(1.0, 25.0, 0.5) var phase2_speed_mult: float = 12.0

## Множитель скорости в фазе 3
@export_range(1.0, 30.0, 0.5) var phase3_speed_mult: float = 16.0

## Случайное смещение при подходе (манёвры)
@export_range(0, 120, 5) var approach_offset: float = 40.0
@export_range(0.5, 5.0, 0.1) var offset_change_interval: float = 1.2

# ─────────────────────────────────────────────
#  АТАКИ
# ─────────────────────────────────────────────
@export_group("⚔️ Атаки")

## ── Ближний бой ──
@export_subgroup("Ближний бой")
@export var melee_enabled: bool = true
@export_range(0.1, 5.0, 0.1) var melee_cooldown: float = 1.0
## Множитель кулдауна в фазе 2 (< 1.0 = быстрее)
@export_range(0.1, 1.0, 0.05) var melee_cooldown_phase2_mult: float = 0.7
@export_range(0.1, 1.0, 0.05) var melee_cooldown_phase3_mult: float = 0.4
@export var rotation_speed: float = 6.0

## ── Дистанционный бой ──
@export_subgroup("Дистанционный бой")
@export var ranged_enabled: bool = false
@export_range(80, 800, 10) var optimal_shoot_range: float = 300.0
@export_range(0.2, 10.0, 0.1) var shoot_cooldown: float = 2.0
@export var projectile_scene: PackedScene
## Количество снарядов за один залп
@export_range(1, 8, 1) var projectile_burst: int = 1
## Угол разброса залпа (градусы)
@export_range(0, 90, 5) var burst_spread_deg: float = 20.0

## ── Dash / Рывок ──
@export_subgroup("Рывок (Dash)")
@export var dash_enabled: bool = false
@export_range(0.5, 15.0, 0.5) var dash_cooldown: float = 5.0
## Скорость рывка (множитель)
@export_range(5.0, 50.0, 1.0) var dash_speed_mult: float = 25.0
## Длительность рывка (сек)
@export_range(0.05, 0.8, 0.05) var dash_duration: float = 0.2
## Минимальная дистанция для активации рывка
@export_range(50, 500, 10) var dash_min_range: float = 150.0

## ── AoE / Область ──
@export_subgroup("AoE — область вокруг себя")
@export var aoe_enabled: bool = false
@export_range(1.0, 30.0, 0.5) var aoe_cooldown: float = 8.0
## Радиус AoE-атаки
@export_range(50, 400, 10) var aoe_radius: float = 120.0
## Анимация AoE
@export var aoe_anim: String = "AoE"
## Сцена визуального эффекта AoE (опционально)
@export var aoe_effect_scene: PackedScene

## ── Вызов миньонов ──
@export_subgroup("Вызов миньонов")
@export var summon_enabled: bool = false
@export_range(5.0, 60.0, 1.0) var summon_cooldown: float = 15.0
## Сцены миньонов для спавна
@export var minion_scenes: Array[PackedScene] = []
## Сколько миньонов за раз
@export_range(1, 8, 1) var minion_count: int = 2
## Максимум одновременных миньонов (0 = без лимита)
@export_range(0, 20, 1) var max_minions: int = 4
## Анимация вызова
@export var summon_anim: String = "Summon"

# ─────────────────────────────────────────────
#  ENRAGE
# ─────────────────────────────────────────────
@export_group("😡 Enrage")

## Включить режим ярости при низком HP
@export var enrage_enabled: bool = false

## Порог HP% для активации enrage
@export_range(0.0, 0.5, 0.05) var enrage_threshold: float = 0.2

## Множитель скорости в enrage
@export_range(1.0, 5.0, 0.1) var enrage_speed_mult: float = 1.5

## Множитель урона в enrage
@export_range(1.0, 5.0, 0.1) var enrage_damage_mult: float = 2.0

@export var enrage_anim: String = "Enrage"

# ─────────────────────────────────────────────
#  АРЕНА
# ─────────────────────────────────────────────
@export_group("🏟 Арена")

## Ограничить зону боя (босс не выходит за пределы)
@export var arena_enabled: bool = false

## Центр арены (локальные координаты, Vector2.ZERO = позиция спавна)
@export var arena_center: Vector2 = Vector2.ZERO

## Радиус арены
@export_range(100, 2000, 50) var arena_radius: float = 500.0

# ─────────────────────────────────────────────
#  АНИМАЦИИ
# ─────────────────────────────────────────────
@export_group("🎬 Анимации")

@export var anim_idle: String   = "Idle"
@export var anim_walk: String   = "Walk"
@export var anim_attack: String = "Attack"
@export var anim_shoot: String  = "Shoot"
@export var anim_dash: String   = "Dash"
@export var anim_death: String  = "Death"
@export_range(1.0, 10.0, 0.5) var death_linger_time: float = 5.0

# ─────────────────────────────────────────────
#  ЗВУКИ
# ─────────────────────────────────────────────
@export_group("🔊 Звуки")

@export var sound_enabled: bool = false
@export var aggro_sounds: Array[AudioStream]  = []
@export var attack_sounds: Array[AudioStream] = []
@export var hurt_sounds: Array[AudioStream]   = []
@export var death_sounds: Array[AudioStream]  = []
@export var phase_sounds: Array[AudioStream]  = []   ## Звук смены фазы
@export var enrage_sounds: Array[AudioStream] = []
@export var summon_sounds: Array[AudioStream] = []

# ─────────────────────────────────────────────
#  ДРОП
# ─────────────────────────────────────────────
@export_group("💀 Дроп")

@export_range(0.0, 1.0, 0.05) var drop_chance: float = 1.0
