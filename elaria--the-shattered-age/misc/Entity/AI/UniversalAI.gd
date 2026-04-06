# UniversalAI.gd
# Универсальный AI — обрабатывает все типы существ через EntityConfig
extends Enemy
class_name UniversalAI

# ─────────────────────────────────────────────
#  ЭКСПОРТЫ
# ─────────────────────────────────────────────
@export var config: EntityConfig
@export var can_move: bool = true

@export_group("🔧 Ноды")
@export var body_anim: AnimationPlayer
@export var hand_anim: AnimationPlayer

@onready var health_bar: ProgressBar = $HealthBar

# ─────────────────────────────────────────────
#  МАШИНА СОСТОЯНИЙ
# ─────────────────────────────────────────────
enum State {
	IDLE,
	WANDER,
	CHASE,
	ATTACK,
	FLEE,
	CALMING_DOWN,
	SCARED,
	DEAD,
	# Новые состояния
	FUSING,      ## Камикадзе: детонирует
	CHARGING,    ## Таран: разгоняется
	RAMMING,     ## Таран: в ударе
	RAM_RECOVER, ## Таран: откат
	TOUCHING,    ## Контактный: касается игрока
}

var state: State = State.IDLE
var player: Node2D

# ─────────────────────────────────────────────
#  ВНУТРЕННИЕ ТАЙМЕРЫ
# ─────────────────────────────────────────────
var _offset_timer: float = 0.0
var _wander_timer: float = 0.0
var _calm_timer: float = 0.0
var _sound_timer: float = 0.0
var _next_idle_sound: float = 0.0
var _aggro_played: bool = false
var _shoot_timer: float = 0.0
var _attack_timer: float = 0.0
var _time_in_state: float = 0.0

# Данные манёвра
var _move_offset: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _is_wander_moving: bool = false

# Камикадзе
var _fuse_timer: float = 0.0
var _exploded: bool = false

# Таран
var _ram_timer: float = 0.0
var _ram_cooldown_timer: float = 0.0
var _ram_direction: Vector2 = Vector2.ZERO
var _ram_recover_timer: float = 0.0

# Контактный
var _touch_timer: float = 0.0
var _is_touching_player: bool = false

# Внутренние ноды
var _audio: AudioStreamPlayer2D
var _hitbox: Area2D

const MOVEMENT_THRESHOLD: float = 5.0

# ─────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────
func _ready() -> void:
	assert(config != null, "UniversalAI: Назначь EntityConfig в инспекторе!")

	player = get_tree().get_first_node_in_group("Player")

	if has_node("HitBox"):
		_hitbox = $HitBox
	if has_node("SFX"):
		_audio = $SFX

	_init_health()

	connect("health_changed", _on_health_changed)
	connect("died", _on_died)

	_pick_wander_target()

	if config.sound_enabled:
		_reset_idle_sound_timer()

	_setup_groups()

	# Подключаем область касания для TOUCH_ATTACKER
	if config.creature_type == EntityConfig.CreatureType.TOUCH_ATTACKER:
		_setup_touch_detection()

	_set_state(State.WANDER)


func _setup_groups() -> void:
	match config.creature_type:
		EntityConfig.CreatureType.MELEE_ENEMY, \
		EntityConfig.CreatureType.RANGED_ENEMY, \
		EntityConfig.CreatureType.KAMIKAZE, \
		EntityConfig.CreatureType.RAM, \
		EntityConfig.CreatureType.TOUCH_ATTACKER:
			pass  # уже в группе "Ennemy" от Enemy
		_:
			remove_from_group("Ennemy")
			add_to_group("Peaceful")


func _setup_touch_detection() -> void:
	# Ожидаем HurtBox (тело существа) — соединяем сигналы входа/выхода игрока
	var hurtbox: Area2D = get_node_or_null("HurtBox")
	if hurtbox:
		hurtbox.body_entered.connect(_on_touch_body_entered)
		hurtbox.body_exited.connect(_on_touch_body_exited)


# ─────────────────────────────────────────────
#  ИНИЦИАЛИЗАЦИЯ ЗДОРОВЬЯ
# ─────────────────────────────────────────────
func _init_health() -> void:
	if not health_bar:
		return
	var multiplier: float = max(enemy_lvl, 1.0)
	Entity_stats.current_health = Entity_stats.max_health * multiplier
	health_bar.max_value = Entity_stats.max_health * multiplier
	health_bar.value = Entity_stats.current_health
	health_bar.visible = false


# ─────────────────────────────────────────────
#  ГЛАВНЫЙ ЦИКЛ
# ─────────────────────────────────────────────
func _process(delta: float) -> void:
	if not is_alive or state == State.DEAD:
		return

	if player == null:
		player = get_tree().get_first_node_in_group("Player")

	_time_in_state += delta

	var dist: float = INF
	if player:
		dist = global_position.distance_to(player.global_position)

	# ── Диспетчер типов ──
	match config.creature_type:
		EntityConfig.CreatureType.MELEE_ENEMY:
			_tick_melee(delta, dist)
		EntityConfig.CreatureType.RANGED_ENEMY:
			_tick_ranged(delta, dist)
		EntityConfig.CreatureType.KAMIKAZE:
			_tick_kamikaze(delta, dist)
		EntityConfig.CreatureType.RAM:
			_tick_ram(delta, dist)
		EntityConfig.CreatureType.TOUCH_ATTACKER:
			_tick_touch_attacker(delta, dist)
		EntityConfig.CreatureType.FLEEING:
			_tick_fleeing(delta, dist)
		EntityConfig.CreatureType.PEACEFUL, \
		EntityConfig.CreatureType.MERCHANT:
			_tick_peaceful(delta, dist)

	_update_flip()
	_handle_sounds(delta)
	move_and_slide()


# ─────────────────────────────────────────────
#  БЛИЖНИЙ БОЙ
# ─────────────────────────────────────────────
func _tick_melee(delta: float, dist: float) -> void:
	if not _player_in_range(dist):
		_do_wander(delta)
		return

	_try_aggro()
	_set_state(State.CHASE)
	_play_body(config.anim_walk)
	_update_approach_offset(delta)

	if can_move:
		_move_toward_player(delta, config.chase_speed_mult)

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


# ─────────────────────────────────────────────
#  ДИСТАНЦИОННЫЙ БОЙ
# ─────────────────────────────────────────────
func _tick_ranged(delta: float, dist: float) -> void:
	if not _player_in_range(dist):
		_do_wander(delta)
		return

	_try_aggro()
	_set_state(State.CHASE)
	_play_body(config.anim_walk)
	_update_approach_offset(delta)

	_move_toward_player(delta, config.chase_speed_mult)
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


# ─────────────────────────────────────────────
#  КАМИКАДЗЕ 💣
#  Бежит к игроку → когда в explosion_trigger_range → отсчёт → взрыв AOE
# ─────────────────────────────────────────────
func _tick_kamikaze(delta: float, dist: float) -> void:
	if _exploded:
		return

	match state:
		State.CHASE:
			if not _player_in_range(dist):
				_do_wander(delta)
				return

			_try_aggro()
			_play_body(config.anim_walk)
			_move_toward_player(delta, config.chase_speed_mult)

			if dist <= config.explosion_trigger_range:
				_set_state(State.FUSING)
				_play_body(config.anim_explode)
				_play_sound_event(config.explosion_sounds)

		State.FUSING:
			# Стоим и ждём взрыва — небольшое дрожание для визуала
			velocity = Vector2.ZERO
			_fuse_timer += delta
			if _fuse_timer >= config.explosion_fuse_time:
				_explode()

		_:  # WANDER → переходим в CHASE если видим игрока
			if _player_in_range(dist):
				_set_state(State.CHASE)
			else:
				_do_wander(delta)


func _explode() -> void:
	if _exploded:
		return
	_exploded = true

	# Спавн VFX
	if config.explosion_vfx_scene:
		var vfx := config.explosion_vfx_scene.instantiate()
		vfx.global_position = global_position
		get_parent().add_child(vfx)

	# Наносим урон всем в радиусе
	var targets_hit: Array[Node] = []

	# Игрок
	if player and global_position.distance_to(player.global_position) <= config.explosion_radius:
		if player.has_method("take_damage"):
			player.take_damage(config.explosion_damage, self)
		targets_hit.append(player)

	# Враги (friendly fire)
	if config.explosion_hits_enemies:
		for enemy in get_tree().get_nodes_in_group("Ennemy"):
			if enemy == self or not is_instance_valid(enemy):
				continue
			if global_position.distance_to(enemy.global_position) <= config.explosion_radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(config.explosion_damage, self)

	# Окружение (объекты с методом take_damage в группе "Destructible")
	for obj in get_tree().get_nodes_in_group("Destructible"):
		if not is_instance_valid(obj):
			continue
		if global_position.distance_to(obj.global_position) <= config.explosion_radius:
			if obj.has_method("take_damage"):
				obj.take_damage(config.explosion_damage, self)

	# Умираем
	_force_die()


# ─────────────────────────────────────────────
#  ТАРАН 🚀
#  Видит игрока → разгоняется → бьёт → откат
# ─────────────────────────────────────────────
func _tick_ram(delta: float, dist: float) -> void:
	_ram_cooldown_timer = max(0.0, _ram_cooldown_timer - delta)

	match state:
		State.WANDER:
			if _player_in_range(dist) and _ram_cooldown_timer <= 0.0:
				_try_aggro()
				_set_state(State.CHASE)
			else:
				_do_wander(delta)

		State.CHASE:
			_play_body(config.anim_walk)
			_move_toward_player(delta, config.chase_speed_mult)

			# Начинаем разгон если в нужной дистанции
			if dist <= config.ram_charge_range and _ram_cooldown_timer <= 0.0:
				_ram_direction = global_position.direction_to(player.global_position)
				_ram_timer = 0.0
				_set_state(State.CHARGING)
				_play_body(config.anim_charge)
				_play_sound_event(config.ram_charge_sounds)

		State.CHARGING:
			_ram_timer += delta
			# Дрожим на месте пока разгоняемся
			velocity = velocity.lerp(Vector2.ZERO, delta * 8.0)
			if _ram_timer >= config.ram_charge_time:
				_set_state(State.RAMMING)

		State.RAMMING:
			_play_body(config.anim_charge)
			velocity = _ram_direction * Entity_stats.move_speed * config.ram_speed_mult

			# Проверка попадания в игрока
			if player and global_position.distance_to(player.global_position) < config.close_range:
				if player.has_method("take_damage"):
					player.take_damage(config.ram_damage, self)
				_play_sound_event(config.ram_impact_sounds)
				_ram_cooldown_timer = config.ram_cooldown
				_ram_recover_timer = config.ram_recovery_time
				_set_state(State.RAM_RECOVER)

			# Если далеко улетели — откат
			if not _player_in_range(dist + 100.0):
				_ram_cooldown_timer = config.ram_cooldown
				_ram_recover_timer = config.ram_recovery_time
				_set_state(State.RAM_RECOVER)

		State.RAM_RECOVER:
			_ram_recover_timer -= delta
			# Тормозим
			velocity = velocity.lerp(Vector2.ZERO, delta * 6.0)
			if _ram_recover_timer <= 0.0:
				_set_state(State.CHASE if _player_in_range(dist) else State.WANDER)


# ─────────────────────────────────────────────
#  КОНТАКТНЫЙ АТАКУЮЩИЙ 👆
#  Касается игрока → тик урона каждые N секунд
# ─────────────────────────────────────────────
func _tick_touch_attacker(delta: float, dist: float) -> void:
	if not _player_in_range(dist):
		_do_wander(delta)
		_is_touching_player = false
		_set_state(State.WANDER)
		return

	_try_aggro()
	_set_state(State.CHASE)
	_play_body(config.anim_walk)
	_move_toward_player(delta, config.chase_speed_mult)

	# Тик урона при касании
	if _is_touching_player:
		_touch_timer += delta
		if _touch_timer >= config.touch_damage_interval:
			_touch_timer = 0.0
			_deal_touch_damage()
		_play_hand(config.anim_attack)
		_set_state(State.TOUCHING)


func _deal_touch_damage() -> void:
	if not player or not is_instance_valid(player):
		return
	if player.has_method("take_damage"):
		player.take_damage(config.touch_damage, self)
	_play_sound_event(config.attack_sounds)

	if config.touch_slows_player and player.has_method("apply_slow"):
		player.apply_slow(config.touch_slow_multiplier, config.touch_damage_interval)


func _on_touch_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_is_touching_player = true
		_touch_timer = config.touch_damage_interval  # Первый тик сразу


func _on_touch_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_is_touching_player = false
		_touch_timer = 0.0


# ─────────────────────────────────────────────
#  УБЕГАЮЩИЙ
# ─────────────────────────────────────────────
func _tick_fleeing(delta: float, dist: float) -> void:
	match state:
		State.WANDER:
			if player and dist <= config.close_range:
				_set_state(State.SCARED)
				_play_sound_event(config.scared_sounds)
			else:
				_calm_wander(delta)

		State.SCARED:
			if _time_in_state >= 0.3:
				_set_state(State.FLEE)

		State.FLEE:
			if player:
				var flee_dir := (global_position - player.global_position).normalized()
				velocity = flee_dir * Entity_stats.move_speed * config.flee_speed_mult
				velocity = velocity.rotated(randf_range(-0.35, 0.35))
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
		velocity = global_position.direction_to(_wander_target) * \
				   Entity_stats.move_speed * config.wander_speed_mult
	else:
		velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)


# ─────────────────────────────────────────────
#  МИРНЫЙ / ТОРГОВЕЦ
# ─────────────────────────────────────────────
func _tick_peaceful(delta: float, dist: float) -> void:
	if player and dist <= config.detection_range:
		velocity = Vector2.ZERO
		_play_body(config.anim_idle)
		_play_hand(config.anim_idle)
	else:
		_do_wander(delta)


# ─────────────────────────────────────────────
#  БЛУЖДАНИЕ (общее)
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
#  ХЕЛПЕРЫ ДВИЖЕНИЯ
# ─────────────────────────────────────────────
func _player_in_range(dist: float) -> bool:
	return player != null and dist <= config.detection_range


func _try_aggro() -> void:
	if not _aggro_played:
		_aggro_played = true
		_play_sound_event(config.aggro_sounds)


func _update_approach_offset(delta: float) -> void:
	_offset_timer += delta
	if _offset_timer >= config.offset_change_interval:
		_move_offset = Vector2(
			randf_range(-config.approach_offset, config.approach_offset),
			randf_range(-config.approach_offset, config.approach_offset))
		_offset_timer = 0.0


func _move_toward_player(delta: float, speed_mult: float) -> void:
	if not can_move or not player:
		return
	position = position.move_toward(
		player.global_position + _move_offset,
		delta * Entity_stats.move_speed * speed_mult)


# ─────────────────────────────────────────────
#  ХЕЛПЕРЫ ОБЩИЕ
# ─────────────────────────────────────────────
func _set_state(new_state: State) -> void:
	if state != new_state:
		state = new_state
		_time_in_state = 0.0
		# Сбрасываем aggro-флаг при возврате в покой
		if new_state == State.WANDER or new_state == State.IDLE:
			_aggro_played = false


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


func _force_die() -> void:
	if not is_alive:
		return
	Entity_stats.current_health = 0
	_on_died()


# ─────────────────────────────────────────────
#  АНИМАЦИИ
# ─────────────────────────────────────────────
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
	if not config.projectile_scene:
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

	if _hitbox:
		_hitbox.monitoring = true
		await get_tree().create_timer(0.1).timeout
		_hitbox.monitoring = false


# ─────────────────────────────────────────────
#  ПОЛУЧЕНИЕ УРОНА
# ─────────────────────────────────────────────
func take_damage(amount: float, source: Node2D = null) -> void:
	super.take_damage(amount, source)
	if not is_alive:
		return

	_play_sound_event(config.hurt_sounds)

	# Испуг для убегающих
	if config.creature_type == EntityConfig.CreatureType.FLEEING:
		_set_state(State.SCARED)
		_play_sound_event(config.scared_sounds)

	# Камикадзе взрывается при получении урона, если уже детонирует
	if config.creature_type == EntityConfig.CreatureType.KAMIKAZE and \
	   state == State.FUSING:
		_explode()


# ─────────────────────────────────────────────
#  ЗВУКИ
# ─────────────────────────────────────────────
func _handle_sounds(delta: float) -> void:
	if not config.sound_enabled or _audio == null:
		return
	if state not in [State.WANDER, State.IDLE]:
		return
	if config.idle_sounds.is_empty():
		return

	_sound_timer += delta
	if _sound_timer >= _next_idle_sound:
		_play_sound_event(config.idle_sounds)
		_reset_idle_sound_timer()


func _play_sound_event(sounds: Array[AudioStream]) -> void:
	if not config.sound_enabled or _audio == null or sounds.is_empty():
		return
	if _audio.playing:
		return
	_audio.stream = sounds[randi() % sounds.size()]
	_audio.play()


func _reset_idle_sound_timer() -> void:
	_sound_timer = 0.0
	_next_idle_sound = randf_range(config.idle_sound_min, config.idle_sound_max)


# ─────────────────────────────────────────────
#  СИГНАЛЫ ЗДОРОВЬЯ
# ─────────────────────────────────────────────
func _on_health_changed(new_health: float) -> void:
	if health_bar:
		health_bar.visible = true
		health_bar.value = new_health


func _on_died() -> void:
	_set_state(State.DEAD)
	if health_bar:
		health_bar.visible = false

	_play_sound_event(config.death_sounds)

	if has_node("Drop"):
		$Drop._drop_items()

	for box_name in ["HitBox", "HurtBox"]:
		if has_node(box_name):
			get_node(box_name).queue_free()

	if body_anim and body_anim.has_animation(config.anim_death):
		body_anim.play(config.anim_death)
		await get_tree().create_timer(config.death_linger_time).timeout

	queue_free()
