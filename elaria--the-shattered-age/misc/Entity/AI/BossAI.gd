## BossAI.gd
## Универсальный скрипт для боссов.
## Поведение задаётся через @export var config: BossConfig
##
## Требует нод в сцене:
##   - HealthBar: ProgressBar   (обычная или boss-bar)
##   - Skin: Node2D             (для флипа спрайта)
##   - HitBox: Area2D           (с ShotPoint если нужна стрельба)
##   - HurtBox: Area2D
##   - AudioStreamPlayer2D      (если нужны звуки)

extends Enemy
class_name BossAI

# ─────────────────────────────────────────────
#  КОНФИГ
# ─────────────────────────────────────────────
@export var config: BossConfig

@export_group("🔧 Ноды")
@export var body_anim: AnimationPlayer
@export var hand_anim: AnimationPlayer
@onready var health_bar: ProgressBar = $HealthBar

# ─────────────────────────────────────────────
#  СОСТОЯНИЯ
# ─────────────────────────────────────────────
enum State {
	IDLE,
	CHASE,
	MELEE_ATTACK,
	RANGED_ATTACK,
	DASH,
	AOE,
	SUMMON,
	PHASE_TRANSITION,
	ENRAGE,
	DEAD
}

var state: State = State.IDLE
var current_phase: int = 1       ## 1 / 2 / 3
var is_enraged: bool = false

var player: Node2D
var _arena_origin: Vector2       ## Центр арены (устанавливается в _ready)

# ─────────────────────────────────────────────
#  ТАЙМЕРЫ
# ─────────────────────────────────────────────
var _melee_timer:  float = 0.0
var _shoot_timer:  float = 0.0
var _dash_timer:   float = 0.0
var _aoe_timer:    float = 0.0
var _summon_timer: float = 0.0
var _offset_timer: float = 0.0
var _state_timer:  float = 0.0   ## Время в текущем состоянии

var _dash_active:   bool    = false
var _dash_elapsed:  float   = 0.0
var _dash_dir:      Vector2 = Vector2.ZERO
var _move_offset:   Vector2 = Vector2.ZERO

var _minion_count:  int = 0      ## Текущее кол-во живых миньонов
var _audio: AudioStreamPlayer2D
var _hitbox: Area2D

const MOVEMENT_THRESHOLD: float = 5.0

# ─────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────
func _ready() -> void:
	assert(config != null, "BossAI: Назначь BossConfig в инспекторе!")

	player = get_tree().get_first_node_in_group("Player")

	if has_node("HitBox"):
		_hitbox = $HitBox
	if has_node("AudioStreamPlayer2D"):
		_audio = $AudioStreamPlayer2D

	# Запоминаем центр арены (мировые координаты)
	_arena_origin = global_position + config.arena_center

	# Здоровье
	_init_health()

	connect("health_changed", _on_health_changed)
	connect("died", _on_died)

	add_to_group("Boss")

	_set_state(State.IDLE)


func _init_health() -> void:
	if not health_bar:
		return
	var mult: float = enemy_lvl if enemy_lvl > 1 else 1.0
	Entity_stats.current_health = Entity_stats.max_health * mult
	health_bar.max_value        = Entity_stats.max_health * mult
	health_bar.value            = Entity_stats.current_health
	if enemy_lvl > 1:
		Entity_stats.attack_power *= enemy_lvl

# ─────────────────────────────────────────────
#  ГЛАВНЫЙ ЦИКЛ
# ─────────────────────────────────────────────
func _process(delta: float) -> void:
	if not is_alive or state == State.DEAD:
		return

	if player == null:
		player = get_tree().get_first_node_in_group("Player")

	_state_timer += delta

	var dist: float = INF
	if player:
		dist = global_position.distance_to(player.global_position)

	# ── Фазы ──
	_check_phase_transition()

	# ── Машина состояний ──
	match state:
		State.IDLE:
			_tick_idle(dist)
		State.CHASE:
			_tick_chase(delta, dist)
		State.MELEE_ATTACK:
			_tick_melee_attack(delta, dist)
		State.RANGED_ATTACK:
			_tick_ranged_attack(delta, dist)
		State.DASH:
			_tick_dash(delta)
		State.AOE:
			_tick_aoe(delta)
		State.SUMMON:
			_tick_summon(delta)
		State.PHASE_TRANSITION:
			_tick_phase_transition(delta)
		State.ENRAGE:
			_tick_enrage(delta, dist)

	# ── Таймеры способностей (тикают всегда пока жив) ──
	_tick_ability_timers(delta)

	# ── Арена ──
	if config.arena_enabled:
		_clamp_to_arena()

	# ── Флип спрайта ──
	_update_flip()

	move_and_slide()


# ─────────────────────────────────────────────
#  СОСТОЯНИЯ
# ─────────────────────────────────────────────
func _tick_idle(dist: float) -> void:
	_play_body(config.anim_idle)
	if player and dist <= config.detection_range:
		_play_sound_event(config.aggro_sounds)
		_set_state(State.CHASE)


func _tick_chase(delta: float, dist: float) -> void:
	if player == null:
		_set_state(State.IDLE)
		return

	_play_body(config.anim_walk)

	# Манёвры
	_offset_timer += delta
	if _offset_timer >= config.offset_change_interval:
		_move_offset = Vector2(
			randf_range(-config.approach_offset, config.approach_offset),
			randf_range(-config.approach_offset, config.approach_offset))
		_offset_timer = 0.0

	var speed := _current_speed()
	position = position.move_toward(
		player.global_position + _move_offset,
		delta * Entity_stats.move_speed * speed)

	# Выбор следующего действия
	_try_abilities(dist)


func _tick_melee_attack(delta: float, dist: float) -> void:
	_rotate_hitbox_toward(player.global_position, delta)

	if _state_timer >= _current_melee_cooldown():
		_play_sound_event(config.attack_sounds)
		_play_hand(config.anim_attack)
		_set_state(State.CHASE)

	# Если игрок вышел из зоны — прерываем
	if dist > config.melee_range * 1.5:
		_set_state(State.CHASE)


func _tick_ranged_attack(delta: float, _dist: float) -> void:
	_rotate_hitbox_toward(player.global_position, delta)

	if _state_timer >= config.shoot_cooldown:
		_fire_burst()
		_set_state(State.CHASE)


func _tick_dash(delta: float) -> void:
	if not _dash_active:
		return

	_play_body(config.anim_dash)
	_dash_elapsed += delta

	velocity = _dash_dir * Entity_stats.move_speed * config.dash_speed_mult

	if _dash_elapsed >= config.dash_duration:
		_dash_active  = false
		_dash_elapsed = 0.0
		velocity      = Vector2.ZERO
		_set_state(State.CHASE)


func _tick_aoe(delta: float) -> void:
	if _state_timer >= 0.6:   ## Небольшая задержка — удар в конце анимации
		_execute_aoe()
		_set_state(State.CHASE)


func _tick_summon(delta: float) -> void:
	if _state_timer >= 0.8:
		_spawn_minions()
		_set_state(State.CHASE)


func _tick_phase_transition(delta: float) -> void:
	velocity = Vector2.ZERO
	if _state_timer >= config.phase_transition_duration:
		# Снимаем неуязвимость (если есть set_invincible в Entity)
		if has_method("set_invincible"):
			call("set_invincible", false)
		_set_state(State.CHASE)


func _tick_enrage(delta: float, dist: float) -> void:
	# Enrage не останавливает остальную логику — просто Chase с бонусами
	_tick_chase(delta, dist)


# ─────────────────────────────────────────────
#  ТАЙМЕРЫ СПОСОБНОСТЕЙ (тикают независимо)
# ─────────────────────────────────────────────
func _tick_ability_timers(delta: float) -> void:
	_melee_timer  += delta
	_shoot_timer  += delta
	_dash_timer   += delta
	_aoe_timer    += delta
	_summon_timer += delta


func _try_abilities(dist: float) -> void:
	if state != State.CHASE and state != State.ENRAGE:
		return

	# Приоритет: AoE > Dash > Summon > Melee > Ranged

	# AoE (если в зоне поражения)
	if config.aoe_enabled and _aoe_timer >= config.aoe_cooldown:
		if dist <= config.aoe_radius * 1.2:
			_aoe_timer = 0.0
			_play_body(config.aoe_anim)
			_set_state(State.AOE)
			return

	# Dash (если далеко)
	if config.dash_enabled and _dash_timer >= config.dash_cooldown:
		if dist >= config.dash_min_range:
			_dash_timer   = 0.0
			_dash_active  = true
			_dash_elapsed = 0.0
			_dash_dir     = global_position.direction_to(player.global_position)
			_set_state(State.DASH)
			return

	# Вызов миньонов
	if config.summon_enabled and _summon_timer >= config.summon_cooldown:
		var active := (config.max_minions == 0 or _minion_count < config.max_minions)
		if active and not config.minion_scenes.is_empty():
			_summon_timer = 0.0
			_play_body(config.summon_anim)
			_play_sound_event(config.summon_sounds)
			_set_state(State.SUMMON)
			return

	# Ближний бой
	if config.melee_enabled and dist <= config.melee_range:
		if _melee_timer >= _current_melee_cooldown():
			_melee_timer = 0.0
			_set_state(State.MELEE_ATTACK)
			return

	# Дистанционный
	if config.ranged_enabled and dist <= config.optimal_shoot_range:
		if _shoot_timer >= config.shoot_cooldown:
			_shoot_timer = 0.0
			_set_state(State.RANGED_ATTACK)
			return


# ─────────────────────────────────────────────
#  ФАЗЫ
# ─────────────────────────────────────────────
func _check_phase_transition() -> void:
	if state == State.PHASE_TRANSITION or state == State.DEAD:
		return

	var hp_pct: float = Entity_stats.current_health / Entity_stats.max_health

	# Enrage
	if config.enrage_enabled and not is_enraged and hp_pct <= config.enrage_threshold:
		_activate_enrage()
		return

	var new_phase := current_phase

	if config.phase_count >= 3 and current_phase < 3 and hp_pct <= config.phase3_threshold:
		new_phase = 3
	elif config.phase_count >= 2 and current_phase < 2 and hp_pct <= config.phase2_threshold:
		new_phase = 2

	if new_phase != current_phase:
		_enter_phase(new_phase)


func _enter_phase(phase: int) -> void:
	current_phase = phase
	_play_sound_event(config.phase_sounds)

	# Кратковременная неуязвимость
	if has_method("set_invincible"):
		call("set_invincible", true)

	if body_anim and body_anim.has_animation(config.phase_transition_anim):
		_play_body(config.phase_transition_anim)

	_set_state(State.PHASE_TRANSITION)


func _activate_enrage() -> void:
	is_enraged = true
	_play_sound_event(config.enrage_sounds)
	if body_anim and body_anim.has_animation(config.enrage_anim):
		_play_body(config.enrage_anim)
	_set_state(State.ENRAGE)


func _current_speed() -> float:
	var base := config.chase_speed_mult
	if is_enraged:
		base *= config.enrage_speed_mult
	match current_phase:
		2: return config.phase2_speed_mult * (config.enrage_speed_mult if is_enraged else 1.0)
		3: return config.phase3_speed_mult * (config.enrage_speed_mult if is_enraged else 1.0)
	return base


func _current_melee_cooldown() -> float:
	var base := config.melee_cooldown
	match current_phase:
		2: base *= config.melee_cooldown_phase2_mult
		3: base *= config.melee_cooldown_phase3_mult
	if is_enraged:
		base *= 0.6
	return base


# ─────────────────────────────────────────────
#  АТАКИ
# ─────────────────────────────────────────────
func _fire_burst() -> void:
	if config.projectile_scene == null or player == null:
		return

	_play_sound_event(config.attack_sounds)

	var shot_point: Node2D = null
	if _hitbox and _hitbox.has_node("ShotPoint"):
		shot_point = _hitbox.get_node("ShotPoint")
	var origin := shot_point.global_position if shot_point else global_position

	var base_dir := (player.global_position - origin).normalized()
	var count    := config.projectile_burst
	var spread   := deg_to_rad(config.burst_spread_deg)

	for i in count:
		var angle_offset := 0.0
		if count > 1:
			angle_offset = lerp(-spread / 2.0, spread / 2.0, float(i) / (count - 1))
		var dir    := base_dir.rotated(angle_offset)
		var bullet := config.projectile_scene.instantiate()

		if bullet.has_method("setup") and _hitbox and _hitbox.get("equip") != null:
			bullet.setup(origin, dir, _hitbox.equip.Damage, _hitbox.equip.projectile_speed)
		else:
			bullet.global_position = origin
			if bullet.get("direction") != null:
				bullet.direction = dir

		get_parent().add_child(bullet)

	if hand_anim and hand_anim.has_animation(config.anim_shoot):
		hand_anim.play(config.anim_shoot)


func _execute_aoe() -> void:
	if config.aoe_effect_scene:
		var fx := config.aoe_effect_scene.instantiate()
		fx.global_position = global_position
		get_parent().add_child(fx)

	# Урон всем в зоне
	var bodies := get_tree().get_nodes_in_group("Player")
	for body in bodies:
		if body is Node2D:
			var d := global_position.distance_to(body.global_position)
			if d <= config.aoe_radius and body.has_method("take_damage"):
				var dmg = Entity_stats.attack_power
				if is_enraged:
					dmg *= config.enrage_damage_mult
				body.take_damage(dmg, self)

	_play_sound_event(config.attack_sounds)


func _spawn_minions() -> void:
	if config.minion_scenes.is_empty():
		return

	for i in config.minion_count:
		if config.max_minions > 0 and _minion_count >= config.max_minions:
			break

		var scene := config.minion_scenes[randi() % config.minion_scenes.size()]
		var minion := scene.instantiate()

		# Случайная позиция вокруг босса
		var angle    := randf_range(0, TAU)
		var distance := randf_range(60.0, 150.0)
		minion.global_position = global_position + Vector2(cos(angle), sin(angle)) * distance

		get_parent().add_child(minion)
		_minion_count += 1

		# Следим за смертью миньона
		if minion.has_signal("died"):
			minion.died.connect(func(): _minion_count = max(0, _minion_count - 1))


# ─────────────────────────────────────────────
#  АРЕНА
# ─────────────────────────────────────────────
func _clamp_to_arena() -> void:
	var to_center := global_position - _arena_origin
	if to_center.length() > config.arena_radius:
		global_position = _arena_origin + to_center.normalized() * config.arena_radius


# ─────────────────────────────────────────────
#  ВСПОМОГАТЕЛЬНЫЕ
# ─────────────────────────────────────────────
func _set_state(new_state: State) -> void:
	if state != new_state:
		state        = new_state
		_state_timer = 0.0


func _rotate_hitbox_toward(target_pos: Vector2, delta: float) -> void:
	if _hitbox == null:
		return
	var target_angle := (target_pos - global_position).angle()
	_hitbox.rotation = lerp_angle(_hitbox.rotation, target_angle, config.rotation_speed * delta)


func _update_flip() -> void:
	if not has_node("Skin") or player == null:
		return
	$Skin.scale.x = 1 if global_position.x < player.global_position.x else -1


func _play_body(anim: String) -> void:
	if body_anim and body_anim.has_animation(anim) and body_anim.current_animation != anim:
		body_anim.play(anim)


func _play_hand(anim: String) -> void:
	if hand_anim and hand_anim.has_animation(anim) and hand_anim.current_animation != anim:
		hand_anim.play(anim)


func _play_sound_event(sounds: Array[AudioStream]) -> void:
	if not config.sound_enabled or _audio == null or sounds.is_empty():
		return
	if _audio.playing:
		return
	_audio.stream = sounds[randi() % sounds.size()]
	_audio.play()


# ─────────────────────────────────────────────
#  УРОН И СМЕРТЬ
# ─────────────────────────────────────────────
func take_damage(amount: float, source: Node2D = null) -> void:
	if state == State.PHASE_TRANSITION:
		return   ## Неуязвимость при смене фазы
	super.take_damage(amount, source)
	if not is_alive:
		return
	_play_sound_event(config.hurt_sounds)


func _on_health_changed(new_health: float) -> void:
	if health_bar:
		health_bar.value = new_health


func _on_died() -> void:
	_set_state(State.DEAD)
	_play_sound_event(config.death_sounds)

	if health_bar:
		health_bar.visible = false

	if randf() <= config.drop_chance:
		if has_node("Drop") and $Drop.has_method("exp_drop"):
			$Drop.exp_drop()

	for box in ["HitBox", "HurtBox"]:
		if has_node(box):
			get_node(box).queue_free()

	if body_anim and body_anim.has_animation(config.anim_death):
		body_anim.play(config.anim_death)
		await get_tree().create_timer(config.death_linger_time).timeout

	queue_free()
