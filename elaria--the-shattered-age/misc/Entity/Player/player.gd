extends Entity
class_name Player

const anim_speed_scale = 1.5
const hand_anim_speed_scale = 1.0

var stamina: float = 100

# ─────────────────────────────────────────
#  Скорость (мультипликаторы для консоли)
# ─────────────────────────────────────────
var standart_speed: float = 10.0
var slow_speed:     float = 7.0
var dash_speed:     float = 20.0

# ─────────────────────────────────────────
#  Нарастание / угасание скорости
# ─────────────────────────────────────────

## Как быстро набирается скорость (выше = резче старт)
@export_range(1.0, 40.0) var acceleration: float = 12.0

## Как быстро гасится скорость при отпускании (выше = резче стоп)
@export_range(1.0, 40.0) var deceleration: float = 18.0

# Текущая плавная скорость (интерполируется каждый кадр)
var _current_velocity: Vector2 = Vector2.ZERO

# ─────────────────────────────────────────
#  Скольжение
# ─────────────────────────────────────────

## Включить/выключить систему скольжения
@export var slide_enabled: bool = true

## Минимальная скорость для старта скольжения (доля от max_speed)
@export_range(0.1, 1.0) var slide_min_speed_ratio: float = 0.4

## Ускорение при старте скольжения (множитель)
@export_range(1.0, 3.0) var slide_speed_boost: float = 1.6

## Длительность скольжения (сек)
@export_range(0.1, 2.0) var slide_duration: float = 0.5

## Трение скольжения (меньше = дольше едет)
@export_range(0.5, 20.0) var slide_friction: float = 4.0

var _is_sliding:     bool    = false
var _slide_timer:    float   = 0.0
var _slide_velocity: Vector2 = Vector2.ZERO

@onready var progress_bar: ProgressBar = $HUD/ProgressBar
@onready var hud: CanvasLayer = $HUD
@onready var health_bar: HealthBar = $HUD/HealthBar
@onready var skin = $Skin
@onready var hit_box: player_HitBox = %player_HitBox
@onready var defense_label: Label = $HUD/HealthBar/Deffense/Label
@onready var death_menu: Control = $HUD/DeathMenu
@onready var effect_display_ui: EffectDisplayUI = $HUD/EffectDisplayUI

@export var BodyAnimator : AnimationPlayer
@export var HandAanimator : AnimationPlayer

# ─────────────────────────────────────────
#  Система Wrap (перенос через край карты)
# ─────────────────────────────────────────

## Включить/выключить Wrap
@export var enable_wrap: bool = true

## Границы карты. Если (0,0,0,0) — используется размер Viewport автоматически
@export var map_bounds: Rect2 = Rect2(0, 0, 0, 0)

# ─────────────────────────────────────────

var dir: Vector2 = Vector2.ZERO
var mouse_pos: Vector2 = Vector2.ZERO
var is_attack : bool = false
var is_holding_attack: bool = false
var save_and_load = SaveSystem.new()

func _ready() -> void:
	super._ready()
	get_tree().get_first_node_in_group("DebugObject").update()
	defense_label.text = str(clamp(Entity_stats.base_defense_modifier * 10, 0, 1))
	save_and_load.load_player(self)
	save_and_load.load_save(Global.player_name)
	if Entity_stats.current_health <= 0:
		Entity_stats.current_health = Entity_stats.max_health / 3
		_on_health_changed(Entity_stats.current_health)
	
	
	# ── Синхронизируем HealthBar с новой системой ──────────────────────────
	# HP игрока всегда 0–100, сердца — только визуальное деление
	health_bar.set_hp(_hp_to_display(Entity_stats.current_health))

	Global.developer_console.register_command("set_speed",       _cmd_set_speed,                    "Set player speed: set_speed [value]")
	Global.developer_console.register_command("tp",              _cmd_teleport,                     "teleport to position X,Y: tp [x,y]")
	Global.developer_console.register_command("multiply",        _cmd_set_standart_multipilier_speed,"change default movement multiplier value to X")
	Global.developer_console.register_command("slow_multiply",   _cmd_set_slow_multipilier_speed,   "change default movement slow_multiplier value to X")
	Global.developer_console.register_command("dash_multiply",   _cmd_set_dash_multipilier_speed,   "change default movement dash_multiplier value to X")
	Global.developer_console.register_command("scale",           _cmd_scale_change,                 "change player scale by X,Y: scale [x,y]")
	Global.developer_console.register_command("unkillable",      _cmd_unkillable,                   "make unkillable bad guy")
	Global.developer_console.register_command("add_heart",       _cmd_add_heart,                    "add one heart container to health bar")
	Global.developer_console.register_command("slide",           _cmd_toggle_slide,                 "toggle slide on/off")
	effect_display_ui.set_entity(self)

# Переводит HP сущности (0…max_health) в диапазон 0–100 для HealthBar
func _hp_to_display(hp: float) -> float:
	if Entity_stats.max_health <= 0:
		return 0.0
	return clampf(hp / Entity_stats.max_health * 100.0, 0.0, 100.0)

func _physics_process(delta: float) -> void:
	mouse_pos = get_global_mouse_position()
	progress_bar.value = Global.explored_progress[Global.current_location]
	if is_alive:
		_movement(delta)
		_animate()

		if !is_attack:
			hit_box.look_at(mouse_pos)

		if mouse_pos.x > position.x:
			skin.scale.x = scale.x
		else:
			skin.scale.x = -scale.x

	move_and_slide()

	if enable_wrap:
		_apply_wrap()


# ─── Wrap: перенос игрока через края карты ───────────────────────────────────

func _apply_wrap() -> void:
	var bounds := _get_bounds()
	var pos := global_position
	
	# По горизонтали
	if pos.x < bounds.position.x:
		pos.x = bounds.position.x + bounds.size.x
	elif pos.x > bounds.position.x + bounds.size.x:
		pos.x = bounds.position.x
	
	# По вертикали
	if pos.y < bounds.position.y:
		pos.y = bounds.position.y + bounds.size.y
	elif pos.y > bounds.position.y + bounds.size.y:
		pos.y = bounds.position.y
	
	global_position = pos


func _get_bounds() -> Rect2:
	# Если границы не заданы вручную — берём размер экрана (Viewport)
	if map_bounds.size == Vector2.ZERO:
		var vp_size := get_viewport_rect().size
		return Rect2(Vector2.ZERO, vp_size)
	return map_bounds

# ─────────────────────────────────────────────────────────────────────────────

func _movement(delta: float) -> void:
	if Global.is_opened_menu:
		# В меню плавно останавливаемся
		_current_velocity = _current_velocity.move_toward(Vector2.ZERO, deceleration * Entity_stats.move_speed * standart_speed * delta)
		velocity = _current_velocity
		return

	dir = Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown").normalized()

	# ── Скольжение ────────────────────────────────────────────────────────
	if slide_enabled and not _is_sliding:
		if Input.is_action_just_pressed("Slide") and dir != Vector2.ZERO:
			var max_spd := Entity_stats.move_speed * standart_speed
			# Начинаем скольжение только если движемся достаточно быстро
			if _current_velocity.length() >= max_spd * slide_min_speed_ratio:
				_is_sliding     = true
				_slide_timer    = slide_duration
				_slide_velocity = _current_velocity.normalized() * max_spd * slide_speed_boost

	if _is_sliding:
		_slide_timer -= delta
		# Плавно гасим скорость скольжения трением
		_slide_velocity = _slide_velocity.move_toward(
			Vector2.ZERO,
			slide_friction * Entity_stats.move_speed * standart_speed * delta
		)
		velocity = _slide_velocity

		if _slide_timer <= 0.0 or _slide_velocity.length() < 1.0:
			_is_sliding     = false
			_slide_velocity = Vector2.ZERO
			_current_velocity = velocity  # плавно продолжаем из текущей скорости
		return

	# ── Нарастание / угасание ─────────────────────────────────────────────
	var target_velocity: Vector2 = dir * Entity_stats.move_speed * standart_speed

	if dir != Vector2.ZERO:
		# Нарастание: плавно разгоняемся до целевой скорости
		_current_velocity = _current_velocity.move_toward(target_velocity, acceleration * Entity_stats.move_speed * standart_speed * delta)
	else:
		# Угасание: плавно тормозим до нуля
		_current_velocity = _current_velocity.move_toward(Vector2.ZERO, deceleration * Entity_stats.move_speed * standart_speed * delta)

	velocity = _current_velocity
		

func _animate():
	var is_looking_right = mouse_pos.x > position.x
	var is_moving_right = velocity.x > 0
	var is_moving_left = velocity.x < 0

	var is_moving_backward = (is_looking_right and is_moving_left) or (!is_looking_right and is_moving_right)

	if velocity.x != 0 or velocity.y != 0:
		if is_moving_backward:
			BodyAnimator.play("Walk", -1.0, -1.0)
			if !is_attack:
				HandAanimator.play("Walk", -1.0, -1.0)
		else:
			BodyAnimator.play("Walk")
			if !is_attack:
				HandAanimator.play("Walk")
	else:
		BodyAnimator.play("Idle")
		if !is_attack:
			HandAanimator.play("Idle")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("LMB") and !is_attack and !Global.is_opened_menu:
	
		if hit_box.is_weapon and hit_box.equip is equip_data:
			print("wep atk")
			hit_box.look_at(mouse_pos)
			is_attack = true
			HandAanimator.speed_scale = hit_box.equip.Atk_speed
			HandAanimator.play(hit_box.equip.play_anim)
			if hit_box.equip.play_anim == "Attack":
				call_deferred("_start_attack_cooldown",hit_box.equip.one_shot_attack)
			elif hit_box.equip.play_anim == "Shoot":
				$Skin/Body/Hand.look_at(mouse_pos)
				call_deferred("_start_shot_cooldown",hit_box.equip.one_shot_attack)
			
				
		elif hit_box.equip is FoodData:
			is_attack = true
			HandAanimator.play(hit_box.equip.play_anim)
			call_deferred("_start_eat_cooldown")
			
		else:
			is_attack = true
			HandAanimator.play(hit_box.equip.play_anim)
			call_deferred("_start_attack_cooldown", true)


func _start_attack_cooldown(one_shot: bool) -> void:
	print("start atk " + str(is_attack))
	await HandAanimator.animation_finished
	is_attack = false
	
	hit_box.look_at(mouse_pos)
	
	if !one_shot and Input.is_action_pressed("LMB") and hit_box.is_weapon and hit_box.equip is equip_data:
		is_attack = true
		HandAanimator.speed_scale = hit_box.equip.Atk_speed
		HandAanimator.play(hit_box.play_anim)
		call_deferred("_start_attack_cooldown", false)
		hit_box.look_at(mouse_pos)
	else:
		is_attack = false
		hit_box.look_at(mouse_pos)


func _start_shot_cooldown(one_shot: bool) -> void:
	print("start atk " + str(is_attack))
	await HandAanimator.animation_finished
	is_attack = false
	$Skin/Body/Hand.look_at(mouse_pos)
	hit_box.look_at(mouse_pos)
	
	if !one_shot and Input.is_action_pressed("LMB") and hit_box.is_weapon and hit_box.equip is equip_data:
		is_attack = true
		HandAanimator.speed_scale = hit_box.equip.Atk_speed
		HandAanimator.play(hit_box.play_anim)
		call_deferred("_start_attack_cooldown", false)
		hit_box.look_at(mouse_pos)
	else:
		is_attack = false
		hit_box.look_at(mouse_pos)
		$Skin/Body/Hand.rotation = 0

func _start_eat_cooldown() -> void:
	await HandAanimator.animation_finished
	is_attack = false

func _shoot_projectile():
	if hit_box.equip.projectile == null:
		print("RangedEnemy: No bullet_scene assigned!")
		return
	
	var bullet = hit_box.equip.projectile.instantiate()
	var bullet_dir = (get_global_mouse_position() - $player_HitBox/Marker2D.global_position).normalized()
	bullet.setup($player_HitBox/Marker2D.global_position, bullet_dir, hit_box.equip.Damage)
	get_parent().add_child(bullet)
	

func save_game():
	save_and_load.save_player(self)


##* signals
func _on_timer_timeout() -> void:
	var play_indx = 1 + randi() % 4
	$Skin/Body/Head/AnimationPlayer.play("Idle" + str(play_indx))
	$Skin/Body/Head/Timer.wait_time = randf_range(3,12)
	$Skin/Body/Head/Timer.start()


######COMANDS

func _cmd_set_speed(args: Array) -> String:
	if args.size() == 1 and args[0].is_valid_float():
		var speed = args[0].to_float()
		Entity_stats.move_speed = speed
		return "Player speed set to " + str(speed)
	return "Usage: set_speed [value]"

func _cmd_set_standart_multipilier_speed(args: Array) -> String:
	if args.size() == 1 and args[0].is_valid_float():
		var speed = args[0].to_float()
		standart_speed = speed
		return "Player multipilier speed set to " + str(speed)
	return "Usage: multiply [value]"

func _cmd_set_slow_multipilier_speed(args: Array) -> String:
	if args.size() == 1 and args[0].is_valid_float():
		var speed = args[0].to_float()
		slow_speed = speed
		return "Player Slow_multipilier speed set to " + str(speed)
	return "Usage: slow_multiply [value]"

func _cmd_set_dash_multipilier_speed(args: Array) -> String:
	if args.size() == 1 and args[0].is_valid_float():
		var speed = args[0].to_float()
		dash_speed = speed
		return "Player dash_multipilier speed set to " + str(speed)
	return "Usage: dash_multiply [value]"

func _cmd_teleport(args: Array) -> String:
	if args.size() == 2 and args[0].is_valid_float() and args[1].is_valid_float():
		var x = args[0].to_float()
		var y = args[1].to_float()
		self.position = Vector2(x, y)
		return "Teleported to (" + str(x) + ", " + str(y) + ")"
	return "Usage: tp [x] [y]"

func _cmd_scale_change(args: Array) -> String:
	if args.size() == 2 and args[0].is_valid_float() and args[1].is_valid_float():
		var x = args[0].to_float()
		var y = args[1].to_float()
		self.scale = Vector2(x, x)
		return "player scale changed to (" + str(x) + ", " + str(y) + ")"
	return "Usage: scale [x] [y]"
	
func _cmd_add_heart(args: Array) -> String:
	var fill := true
	if args.size() == 1 and args[0] == "empty":
		fill = false
	health_bar.add_heart(fill)
	return "Heart container added (%s). Total: %d" % [("full" if fill else "empty"), health_bar.heart_count]

func _cmd_toggle_slide(args: Array) -> String:
	slide_enabled = !slide_enabled
	return "Slide: " + ("ON" if slide_enabled else "OFF")

func _cmd_unkillable(args: Array) -> String:
	var col := $HurtBox/CollisionShape2D
	col.disabled = !col.disabled
	if col.disabled:
		return "you can't receive damage"
	return "you can receive damage"

func shoot() -> void:
	var equip = hit_box.equip as equip_data
	if not equip or not equip.projectile:
		return
	
	var marker_pos = $player_HitBox/Marker2D.global_position
	var mouse_pos = get_global_mouse_position()
	var base_dir = (mouse_pos - marker_pos).normalized()
	
	for i in range(equip.num_projectiles):
		var angle_offset = (randf() - 0.5) * deg_to_rad(equip.spread_degrees)
		var dir = base_dir.rotated(angle_offset)
		
		var bullet = equip.projectile.instantiate() as Projectile
		bullet.shot_target = "Ennemy"
		bullet.setup(
			marker_pos,
			dir,
			equip.Damage,
			equip.projectile_speed,
		)
		
		get_parent().add_child(bullet)
	

func _on_health_changed(new_health: float) -> void:
	health_bar.set_hp(_hp_to_display(new_health))

func _on_died() -> void:
	HandAanimator.stop()
	BodyAnimator.play("Death")
	death_menu.death()

func respawn() -> void:
	Entity_stats.current_health = Entity_stats.max_health / 3
	_on_health_changed(Entity_stats.current_health)
	_current_velocity = Vector2.ZERO
	_is_sliding       = false
	is_alive          = true
