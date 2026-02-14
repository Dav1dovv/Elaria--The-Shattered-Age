## UniversalAI.gd
## Один скрипт для всех существ.
## Поведение задаётся через @export var config: EntityConfig
##
## Совместимость: работает поверх Enemy (extends Enemy).
## Для мирных существ замени на "extends Entity" и убери enemy_lvl логику.

extends Enemy
class_name UniversalAI

# ─────────────────────────────────────────────
#  КОНФИГ — единственное что надо трогать в инспекторе
# ─────────────────────────────────────────────
@export var config: EntityConfig

# ─────────────────────────────────────────────
#  НОДЫ (назначь в инспекторе или оставь авто-поиск)
# ─────────────────────────────────────────────
@export_group("🔧 Ноды")
@export var body_anim: AnimationPlayer
@export var hand_anim: AnimationPlayer
@onready var health_bar: ProgressBar = $HealthBar

# ─────────────────────────────────────────────
#  ВНУТРЕННИЕ ПЕРЕМЕННЫЕ
# ─────────────────────────────────────────────
enum State { IDLE, WANDER, CHASE, ATTACK, FLEE, CALMING_DOWN, SCARED, DEAD }

var state: State = State.IDLE
var player: Node2D

var _offset_timer: float = 0.0
var _wander_timer: float = 0.0
var _calm_timer: float = 0.0
var _sound_timer: float = 0.0
var _next_idle_sound: float = 0.0
var _aggro_played: bool = false   # чтобы aggro-звук играл один раз при входе в chase
var _shoot_timer: float = 0.0
var _attack_timer: float = 0.0   # таймер ближней атаки
var _time_in_state: float = 0.0

var _move_offset: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _is_wander_moving: bool = false

var _audio: AudioStreamPlayer2D
var _hitbox: Area2D

const MOVEMENT_THRESHOLD: float = 5.0

# ─────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────
func _ready() -> void:
	assert(config != null, "UniversalAI: Назначь EntityConfig в инспекторе!")

	player = get_tree().get_first_node_in_group("Player")

	# Ноды
	if has_node("HitBox"):
		_hitbox = $HitBox
	if has_node("SFX"):
		_audio = $SFX

	# Health
	_init_health()

	# Сигналы
	connect("health_changed", _on_health_changed)
	connect("died", _on_died)

	# Первая точка блуждания
	_pick_wander_target()

	# Звук
	if config.sound_enabled:
		_reset_idle_sound_timer()

	# Группы
	match config.creature_type:
		EntityConfig.CreatureType.MELEE_ENEMY, \
		EntityConfig.CreatureType.RANGED_ENEMY:
			pass  # already in "Ennemy" from Enemy._init()
		_:
			remove_from_group("Ennemy")
			add_to_group("Peaceful")

	_set_state(State.WANDER)


func _init_health() -> void:
	if not health_bar:
		return
	var multiplier: float = enemy_lvl if enemy_lvl > 1 else 1.0
	Entity_stats.current_health = Entity_stats.max_health * multiplier
	health_bar.max_value = Entity_stats.max_health * multiplier
	health_bar.value = Entity_stats.current_health
	health_bar.visible = false
	if enemy_lvl > 1:
		Entity_stats.attack_power *= enemy_lvl

# ─────────────────────────────────────────────
#  PROCESS — главный цикл
# ─────────────────────────────────────────────
func _process(delta: float) -> void:
	if not is_alive or state == State.DEAD:
		return

	# Обновляем ссылку на игрока
	if player == null:
		player = get_tree().get_first_node_in_group("Player")

	_time_in_state += delta

	var dist: float = INF
	if player:
		dist = global_position.distance_to(player.global_position)

	# ── Машина состояний ──
	match config.creature_type:
		EntityConfig.CreatureType.MELEE_ENEMY:
			_tick_melee(delta, dist)
		EntityConfig.CreatureType.RANGED_ENEMY:
			_tick_ranged(delta, dist)
		EntityConfig.CreatureType.FLEEING:
			_tick_fleeing(delta, dist)
		EntityConfig.CreatureType.PEACEFUL, \
		EntityConfig.CreatureType.MERCHANT:
			_tick_peaceful(delta, dist)

	# ── Общие системы ──
	_update_flip()
	_handle_sounds(delta)
	move_and_slide()


# ─────────────────────────────────────────────
#  БЛИЖНИЙ БОЙ
# ─────────────────────────────────────────────
func _tick_melee(delta: float, dist: float) -> void:
	if player and dist <= config.detection_range:
		# Aggro-звук при первом обнаружении
		if state != State.CHASE and state != State.ATTACK:
			_play_sound_event(config.aggro_sounds)
		_set_state(State.CHASE)
		_play_body(config.anim_walk)

		# Манёвры
		_offset_timer += delta
		if _offset_timer >= config.offset_change_interval:
			_move_offset = Vector2(
				randf_range(-config.approach_offset, config.approach_offset),
				randf_range(-config.approach_offset, config.approach_offset))
			_offset_timer = 0.0

		position = position.move_toward(
			player.global_position + _move_offset,
			delta * Entity_stats.move_speed * config.chase_speed_mult)

		if dist < config.close_range:
			_set_state(State.ATTACK)
			_rotate_hitbox_toward(player.global_position, delta)
			_attack_timer += delta
			if _attack_timer >= config.attack_cooldown:
				_attack_timer = 0.0
				_play_sound_event(config.attack_sounds)
				_play_hand(config.anim_attack)
		else:
			_play_hand(config.anim_walk)
	else:
		_do_wander(delta)


# ─────────────────────────────────────────────
#  ДИСТАНЦИОННЫЙ БОЙ
# ─────────────────────────────────────────────
func _tick_ranged(delta: float, dist: float) -> void:
	if player and dist <= config.detection_range:
		# Aggro-звук при первом обнаружении
		if state != State.CHASE and state != State.ATTACK:
			_play_sound_event(config.aggro_sounds)
		_set_state(State.CHASE)
		_play_body(config.anim_walk)

		_offset_timer += delta
		if _offset_timer >= config.offset_change_interval:
			_move_offset = Vector2(
				randf_range(-config.approach_offset, config.approach_offset),
				randf_range(-config.approach_offset, config.approach_offset))
			_offset_timer = 0.0

		position = position.move_toward(
			player.global_position + _move_offset,
			delta * Entity_stats.move_speed * config.chase_speed_mult)

		_rotate_hitbox_toward(player.global_position, delta)

		_shoot_timer += delta
		if dist <= config.optimal_shoot_range and _shoot_timer >= config.shoot_cooldown:
			_play_sound_event(config.attack_sounds)
			_shoot()
			_shoot_timer = 0.0
		elif dist < config.close_range:
			_play_hand(config.anim_attack)
		else:
			_play_hand(config.anim_aim)
	else:
		_do_wander(delta)


# ─────────────────────────────────────────────
#  УБЕГАЮЩИЙ
# ─────────────────────────────────────────────
func _tick_fleeing(delta: float, dist: float) -> void:
	match state:
		State.WANDER:
			# Убегаем если игрок слишком близко
			if player and dist <= config.close_range:
				_set_state(State.SCARED)
				_play_sound_event(config.scared_sounds)
			else:
				_calm_wander(delta)

		State.SCARED:
			# Краткая пауза перед побегом
			if _time_in_state >= 0.3:
				_set_state(State.FLEE)

		State.FLEE:
			if player:
				var flee_dir := (global_position - player.global_position).normalized()
				velocity = flee_dir * Entity_stats.move_speed * config.flee_speed_mult
				velocity = velocity.rotated(randf_range(-0.35, 0.35))
			# Успокаиваемся
			if _time_in_state > 3.0 or dist > config.detection_range + 120:
				_calm_timer = config.calm_down_time
				_set_state(State.CALMING_DOWN)

		State.CALMING_DOWN:
			velocity = velocity.lerp(Vector2.ZERO, delta * 5.0)
			_calm_timer -= delta
			if _calm_timer <= 0.0:
				velocity = Vector2.ZERO
				_pick_wander_target()
				_set_state(State.WANDER)

	# Анимация по скорости
	if velocity.length() > MOVEMENT_THRESHOLD:
		_play_body(config.anim_walk)
	else:
		_play_body(config.anim_idle)


func _calm_wander(delta: float) -> void:
	if global_position.distance_to(_wander_target) < 30.0 or \
	   _time_in_state > randf_range(5.0, 12.0):
		if randf() < 0.45:
			velocity = Vector2.ZERO
			if _time_in_state > randf_range(2.0, 7.0):
				_pick_wander_target()
		else:
			_pick_wander_target()

	if global_position.distance_to(_wander_target) >= 30.0:
		var dir := global_position.direction_to(_wander_target)
		velocity = dir * Entity_stats.move_speed * config.wander_speed_mult
	else:
		velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)


# ─────────────────────────────────────────────
#  МИРНЫЙ / ТОРГОВЕЦ
# ─────────────────────────────────────────────
func _tick_peaceful(delta: float, dist: float) -> void:
	if player and dist <= config.detection_range:
		# Останавливается рядом с игроком
		velocity = Vector2.ZERO
		_play_body(config.anim_idle)
		_play_hand(config.anim_idle)
	else:
		_do_wander(delta)


# ─────────────────────────────────────────────
#  БЛУЖДАНИЕ (общее для melee / ranged / peaceful)
# ─────────────────────────────────────────────
func _do_wander(delta: float) -> void:
	_set_state(State.WANDER)
	_wander_timer += delta
	if _wander_timer >= config.wander_interval:
		_is_wander_moving = !_is_wander_moving
		_wander_timer = 0.0
		if _is_wander_moving:
			_move_offset = Vector2(
				randf_range(-config.approach_offset, config.approach_offset),
				randf_range(-config.approach_offset, config.approach_offset))

	if _is_wander_moving:
		_play_body(config.anim_walk)
		_play_hand(config.anim_walk)
		position = position.move_toward(
			global_position + _move_offset,
			delta * Entity_stats.move_speed * config.wander_speed_mult)
	else:
		_play_body(config.anim_idle)
		_play_hand(config.anim_idle)


# ─────────────────────────────────────────────
#  ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ─────────────────────────────────────────────
func _set_state(new_state: State) -> void:
	if state != new_state:
		state = new_state
		_time_in_state = 0.0


func _rotate_hitbox_toward(target_pos: Vector2, delta: float) -> void:
	if _hitbox == null:
		return
	var target_angle := (target_pos - global_position).angle()
	_hitbox.rotation = lerp_angle(_hitbox.rotation, target_angle, config.rotation_speed * delta)


func _update_flip() -> void:
	if not has_node("Skin"):
		return
	if velocity.length() > MOVEMENT_THRESHOLD:
		$Skin.scale.x = sign(velocity.x) if abs(velocity.x) > 10 else $Skin.scale.x
	elif player:
		$Skin.scale.x = 1 if global_position.x < player.global_position.x else -1


func _pick_wander_target() -> void:
	_time_in_state = 0.0
	var angle := randf_range(0.0, TAU)
	var dist  := randf_range(80.0, 250.0)
	_wander_target = global_position + Vector2(cos(angle), sin(angle)) * dist


func _play_body(anim: String) -> void:
	if body_anim and body_anim.has_animation(anim) and body_anim.current_animation != anim:
		body_anim.play(anim)


func _play_hand(anim: String) -> void:
	if hand_anim and hand_anim.has_animation(anim) and hand_anim.current_animation != anim:
		hand_anim.play(anim)


# ─────────────────────────────────────────────
#  СТРЕЛЬБА
# ─────────────────────────────────────────────
func _shoot() -> void:
	if config.projectile_scene == null:
		push_warning("UniversalAI: projectile_scene не назначен!")
		return

	_play_hand(config.anim_shoot)

	var bullet := config.projectile_scene.instantiate()
	var shot_point: Node2D = null
	if _hitbox and _hitbox.has_node("ShotPoint"):
		shot_point = _hitbox.get_node("ShotPoint")

	var origin := shot_point.global_position if shot_point else global_position
	var direction := (player.global_position - origin).normalized()

	if bullet.has_method("setup") and _hitbox and _hitbox.get("equip") != null:
		bullet.setup(origin, direction, _hitbox.equip.Damage, _hitbox.equip.projectile_speed)
	else:
		bullet.global_position = origin
		if bullet.get("direction") != null:
			bullet.direction = direction

	get_parent().add_child(bullet)

	# Кратковременно включаем HitBox
	if _hitbox:
		_hitbox.monitoring = true
		await get_tree().create_timer(0.1).timeout
		_hitbox.monitoring = false


# ─────────────────────────────────────────────
#  ПОЛУЧЕНИЕ УРОНА (переопределение для FLEEING)
# ─────────────────────────────────────────────
func take_damage(amount: float, source: Node2D = null) -> void:
	super.take_damage(amount, source)
	if not is_alive:
		return

	# Звук получения урона
	_play_sound_event(config.hurt_sounds)

	if config.creature_type == EntityConfig.CreatureType.FLEEING:
		_set_state(State.SCARED)
		_play_sound_event(config.scared_sounds)


# ─────────────────────────────────────────────
#  ЗВУКИ
# ─────────────────────────────────────────────

## Вызывается каждый кадр — тикает таймер idle-звуков
func _handle_sounds(delta: float) -> void:
	if not config.sound_enabled or _audio == null:
		return
	# Idle-звуки только в спокойных состояниях
	if state not in [State.WANDER, State.IDLE]:
		return
	if config.idle_sounds.is_empty():
		return

	_sound_timer += delta
	if _sound_timer >= _next_idle_sound:
		_play_sound_event(config.idle_sounds)
		_reset_idle_sound_timer()


## Воспроизводит случайный звук из массива (если звук включён и аудиоплеер есть)
func _play_sound_event(sounds: Array[AudioStream]) -> void:
	if not config.sound_enabled or _audio == null or sounds.is_empty():
		return
	# Не перебиваем уже играющий звук (опционально — убери если нужна очередь)
	if _audio.playing:
		return
	_audio.stream = sounds[randi() % sounds.size()]
	_audio.play()


func _reset_idle_sound_timer() -> void:
	_sound_timer = 0.0
	_next_idle_sound = randf_range(config.idle_sound_min, config.idle_sound_max)


# ─────────────────────────────────────────────
#  СИГНАЛЫ ЗДОРОВЬЯ И СМЕРТИ
# ─────────────────────────────────────────────
func _on_health_changed(new_health: float) -> void:
	if health_bar:
		health_bar.visible = true
		health_bar.value = new_health


func _on_died() -> void:
	_set_state(State.DEAD)

	if health_bar:
		health_bar.visible = false

	# Звук смерти
	_play_sound_event(config.death_sounds)

	# Дроп
	if randf() <= config.drop_chance:
		if has_node("Drop") and $Drop.has_method("exp_drop"):
			$Drop.exp_drop()

	# Удаляем боксы
	for box_name in ["HitBox", "HurtBox"]:
		if has_node(box_name):
			get_node(box_name).queue_free()

	# Анимация смерти
	if body_anim and body_anim.has_animation(config.anim_death):
		body_anim.play(config.anim_death)
		await get_tree().create_timer(config.death_linger_time).timeout

	queue_free()
