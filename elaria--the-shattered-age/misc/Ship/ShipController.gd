extends CharacterBody2D

# ─────────────────────────────────────────
#  Настройки корабля
# ─────────────────────────────────────────
@onready var ray_cast_2d: RayCast2D = $RayCast2D
@onready var sprite: Node2D = $Visual
@onready var ship_ui: ship_healthUI = $ship_UI
@onready var location_label: Label = $ship_UI/Location

## Максимальная скорость движения (пикселей/сек)
@export var max_speed: float = 300.0

## Ускорение — как быстро набирает скорость
@export var acceleration: float = 200.0

## Торможение — как быстро гасит скорость (когда ЛКМ не зажата)
@export var friction: float = 150.0

## Плавность поворота корабля к мыши
@export var rotation_speed: float = 5.0

## Если до мыши меньше этого расстояния — тормозим (чтобы не дёргался на месте)
@export var stop_radius: float = 10.0

# ─────────────────────────────────────────
#  Система Wrap (перенос через край карты)
# ─────────────────────────────────────────

## Включить/выключить Wrap
@export var enable_wrap: bool = true

## Границы карты. Если size == (0,0) — используется размер Viewport автоматически
@export var map_bounds: Rect2 = Rect2(0, 0, 0, 0)

# ─────────────────────────────────────────
#  Система здоровья
# ─────────────────────────────────────────

## Максимальное здоровье корабля
@export var max_health: float = 100.0

## Текущее здоровье
var current_health: float = max_health

signal health_changed(current: float, maximum: float)
signal ship_destroyed()

# ─────────────────────────────────────────
#  Внутреннее состояние
# ─────────────────────────────────────────

var _velocity: Vector2 = Vector2.ZERO

const SAVE_KEY := "ship_position"
const HEALTH_KEY := "ship_health"


func _ready() -> void:
	Global.save_game.connect(_on_save_game)
	Global.load_game.connect(_on_load_game)
	Global.load()
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)


func _physics_process(delta: float) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()

	_rotate_sprite_toward_mouse(mouse_pos, delta)

	if Input.is_action_pressed("RMB"):
		_move_toward_mouse(mouse_pos, delta)
	else:
		_apply_friction(delta)

	position += _velocity * delta
	
	# Wrap применяется после обновления позиции
	if enable_wrap:
		_apply_wrap()
	
	if ray_cast_2d.is_colliding():
		print("founded land")
		location_label.visible = true
		location_label.text = ray_cast_2d.get_collider().location_ID
		if Input.is_action_just_pressed("Land"):
			Global.save()
			ray_cast_2d.get_collider()._interact()
	else:
		location_label.visible = false


# ─── Wrap: перенос корабля через края карты ──────────────────────────────────

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


# ─── Плавный поворот СПРАЙТА к курсору ───────────────────────────────────────

func _rotate_sprite_toward_mouse(mouse_pos: Vector2, delta: float) -> void:
	if not sprite:
		return
	
	var target_angle: float = (mouse_pos - global_position).angle()
	sprite.rotation = lerp_angle(sprite.rotation, target_angle, rotation_speed * delta)


# ─── Движение к позиции мыши ─────────────────────────────────────────────────

func _move_toward_mouse(mouse_pos: Vector2, delta: float) -> void:
	var to_mouse: Vector2 = mouse_pos - global_position
	var distance: float = to_mouse.length()

	if distance < stop_radius:
		_apply_friction(delta)
		return

	var direction: Vector2 = to_mouse.normalized()

	_velocity += direction * acceleration * delta

	if _velocity.length() > max_speed:
		_velocity = _velocity.normalized() * max_speed


# ─── Плавное торможение (трение) ─────────────────────────────────────────────

func _apply_friction(delta: float) -> void:
	var speed: float = _velocity.length()

	if speed > 0.0:
		var brake: float = min(friction * delta, speed)
		_velocity -= _velocity.normalized() * brake


# ═════════════════════════════════════════════════════════════════════════════
#  СИСТЕМА ЗДОРОВЬЯ
# ═════════════════════════════════════════════════════════════════════════════

func take_damage(amount: float) -> void:
	if current_health <= 0:
		return
	
	current_health = max(0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)
	
	print("Ship took %s damage! Health: %s/%s" % [amount, current_health, max_health])
	
	if current_health <= 0:
		_on_ship_destroyed()


func heal(amount: float) -> void:
	if current_health <= 0:
		return
	
	current_health = min(max_health, current_health + amount)
	emit_signal("health_changed", current_health, max_health)
	
	print("Ship healed %s! Health: %s/%s" % [amount, current_health, max_health])


func _on_ship_destroyed() -> void:
	print("Ship destroyed!")
	emit_signal("ship_destroyed")
	set_physics_process(false)


# ─── Сохранение позиции и здоровья ───────────────────────────────────────────

func _on_save_game() -> void:
	var save_path := Global.get_save_path()
	if save_path.is_empty():
		return

	var existing: Dictionary = {}
	if FileAccess.file_exists(save_path):
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				existing = parsed
			file.close()

	existing[SAVE_KEY] = { "x": global_position.x, "y": global_position.y }
	existing[HEALTH_KEY] = current_health

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(existing, "\t"))
		file.close()
		print("ShipController: позиция и здоровье сохранены")
	else:
		print("ShipController: ошибка открытия файла для записи — ", save_path)


# ─── Загрузка позиции и здоровья ─────────────────────────────────────────────

func _on_load_game() -> void:
	var save_path := Global.get_save_path()
	if save_path.is_empty() or not FileAccess.file_exists(save_path):
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		print("ShipController: не удалось открыть файл сохранения")
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed is Dictionary:
		return

	if parsed.has(SAVE_KEY):
		var pos_data: Dictionary = parsed[SAVE_KEY]
		global_position = Vector2(pos_data["x"], pos_data["y"])
		_velocity = Vector2.ZERO
		print("ShipController: позиция загружена %s" % global_position)
	
	if parsed.has(HEALTH_KEY):
		current_health = parsed[HEALTH_KEY]
		emit_signal("health_changed", current_health, max_health)
		print("ShipController: здоровье загружено %s/%s" % [current_health, max_health])
		
		if current_health > 0:
			set_physics_process(true)
