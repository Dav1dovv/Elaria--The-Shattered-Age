extends Entity
class_name Player

const anim_speed_scale = 1.5
const  hand_anim_speed_scale = 1.0

var stamina : float = 100
var multiplier = 10

var standart_speed = 10
var slow_speed = 7
var dash_speed = 20

@onready var hud: CanvasLayer = $HUD
@onready var health_bar: HealthBar = $HUD/HealthBar
@onready var skin = $Skin
@onready var hit_box: player_HitBox = %player_HitBox
@onready var defense_label: Label = $HUD/HealthBar/Deffense/Label
@onready var death_menu: Control = $HUD/DeathMenu
@onready var effect_display_ui: EffectDisplayUI = $HUD/HealthBar/EffectDisplayUI

@export var BodyAnimator : AnimationPlayer
@export var HandAanimator : AnimationPlayer

var dir
var mouse_pos
var is_attack : bool = false
var is_holding_attack: bool = false  # Флаг для удержания кнопки атаки
var save_and_load = SaveSystem.new()

func _ready() -> void:
	super._ready()
	get_tree().get_first_node_in_group("DebugObject").update()
	defense_label.text = str(clamp(Entity_stats.base_defense_modifier*10, 0, 1))
	save_and_load.load_player(self)
	save_and_load.load_save(Global.player_name)
	if Entity_stats.current_health <=0:
		Entity_stats.current_health = Entity_stats.max_health / 3
		_on_health_changed(Entity_stats.current_health)
	Global.developer_console.register_command("set_speed", _cmd_set_speed, "Set player speed: set_speed [value]")
	Global.developer_console.register_command("tp", _cmd_teleport, "teleport to position X,Y: tp [x,y]")
	Global.developer_console.register_command("multiply",_cmd_set_standart_multipilier_speed,"change default movement multipilier value to X")
	Global.developer_console.register_command("slow_multiply",_cmd_set_slow_multipilier_speed,"change default movement slow_multipilier value to X")
	Global.developer_console.register_command("dash_multiply",_cmd_set_dash_multipilier_speed,"change default movement dashd_multipilier value to X")
	Global.developer_console.register_command("scale",_cmd_scale_change,"change player scale by X,Y: scale [x,y]")
	Global.developer_console.register_command("unkillable",_cmd_unkillable,"make unkillable bad guy")
	effect_display_ui.set_entity(self)

func _physics_process(delta: float) -> void:
	mouse_pos = get_global_mouse_position()
	if is_alive:
		var mouse_pos = get_global_mouse_position()
		_movement()
		_animate()

		#$LookZone_point.look_at(mouse_pos)
		if !is_attack:
			hit_box.look_at(mouse_pos)
			
		# Flip sprite based on mouse position
		if mouse_pos.x > position.x:
			skin.scale.x = scale.x
		else:
			skin.scale.x = -scale.x

	move_and_slide()

func _movement():
	if !Global.is_opened_menu:
		dir = Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown").normalized()
		velocity = dir * Entity_stats.move_speed * multiplier
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		

func _animate():
	var is_looking_right = mouse_pos.x > position.x  # true, если смотрит вправо
	var is_moving_right = velocity.x > 0  # true, если движется вправо
	var is_moving_left = velocity.x < 0  # true, если движется влево

	# Проверяем, движется ли игрок и противоположно ли движение взгляду
	var is_moving_backward = (is_looking_right and is_moving_left) or (!is_looking_right and is_moving_right)

	if velocity.x != 0 or velocity.y != 0:  # Если игрок движется
		if is_moving_backward:
			# Вариант 1: Проигрываем анимацию "Walk" задом наперёд
			BodyAnimator.play("Walk", -1.0, -1.0)  # -1.0 для обратного воспроизведения
			if !is_attack:
				HandAanimator.play("Walk", -1.0, -1.0)
		else:
			# Обычная ходьба вперёд
			BodyAnimator.play("Walk")
			if !is_attack:
				HandAanimator.play("Walk")
	else:
		# Состояние покоя
		BodyAnimator.play("Idle")
		if !is_attack:
			HandAanimator.play("Idle")

# Обработка ввода для анимации (переместили из _animate, чтобы избежать await в _physics_process)
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("LMB") and !is_attack and !Global.is_opened_menu:
	
		if hit_box.is_weapon and hit_box.equip is equip_data:
			print("wep atk")
			hit_box.look_at(mouse_pos)
			is_attack = true
			HandAanimator.speed_scale = hit_box.equip.Atk_speed
			HandAanimator.play(hit_box.equip.play_anim)
			if hit_box.equip.play_anim == "Attack":
			# Запускаем отложенное завершение атаки
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
			call_deferred("_start_attack_cooldown", true)  # по умолчанию one-shot


# НОВАЯ функция: запускает ожидание завершения анимации
func _start_attack_cooldown(one_shot: bool) -> void:
	print("start atk " + str(is_attack))
	await HandAanimator.animation_finished
	is_attack = false
	
	hit_box.look_at(mouse_pos)
	
	# Если это НЕ one-shot атака — проверяем, держит ли игрок кнопку
	if !one_shot and Input.is_action_pressed("LMB") and hit_box.is_weapon and hit_box.equip is equip_data:
		is_attack = true
		HandAanimator.speed_scale = hit_box.equip.Atk_speed
		HandAanimator.play(hit_box.play_anim)
		call_deferred("_start_attack_cooldown", false)
		hit_box.look_at(mouse_pos)
	else:
		# Атака завершена
		is_attack = false
		hit_box.look_at(mouse_pos)


func _start_shot_cooldown(one_shot: bool) -> void:
	print("start atk " + str(is_attack))
	await HandAanimator.animation_finished
	is_attack = false
	$Skin/Body/Hand.look_at(mouse_pos)
	hit_box.look_at(mouse_pos)
	
	# Если это НЕ one-shot атака — проверяем, держит ли игрок кнопку
	if !one_shot and Input.is_action_pressed("LMB") and hit_box.is_weapon and hit_box.equip is equip_data:
		is_attack = true
		HandAanimator.speed_scale = hit_box.equip.Atk_speed
		HandAanimator.play(hit_box.play_anim)
		call_deferred("_start_attack_cooldown", false)
		hit_box.look_at(mouse_pos)
	else:
		# Атака завершена
		is_attack = false
		hit_box.look_at(mouse_pos)
		$Skin/Body/Hand.rotation = 0

# Для еды — отдельно
func _start_eat_cooldown() -> void:
	await HandAanimator.animation_finished
	is_attack = false

func _shoot_projectile():
	if hit_box.equip.projectile == null:
		print("RangedEnemy: No bullet_scene assigned!")
		return
	
	# Создание пули
	var bullet = hit_box.equip.projectile.instantiate()

	
	# Направление к цели
	var bullet_dir = (get_global_mouse_position() - $player_HitBox/Marker2D.global_position).normalized()
	
	# Настройка пули
	bullet.setup($player_HitBox/Marker2D.global_position, bullet_dir, hit_box.equip.Damage)
	
	# Добавление в сцену
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
	
func _cmd_unkillable(args:Array) -> String:
	var message
	if $HurtBox/CollisionShape2D.disabled:
		message = "you can revive damage"
		$HurtBox/CollisionShape2D.disabled = false
		return message
	elif !$HurtBox/CollisionShape2D.disabled:
		message = "you can't revive damage"
		$HurtBox/CollisionShape2D.disabled = true
		return message
	return message

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
			equip.projectile_speed,   # ← теперь безопасно
		)
		
		get_parent().add_child(bullet)
	

func _on_health_changed(new_health: float) -> void:
	health_bar.set_value(new_health)

func _on_died() -> void:
	HandAanimator.stop()
	BodyAnimator.play("Death")
	death_menu.death()
