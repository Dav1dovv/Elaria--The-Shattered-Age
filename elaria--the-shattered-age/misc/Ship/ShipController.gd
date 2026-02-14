extends Node2D

# ─────────────────────────────────────────
#  Настройки корабля
# ─────────────────────────────────────────

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
#  Внутреннее состояние
# ─────────────────────────────────────────

var _velocity: Vector2 = Vector2.ZERO


func _physics_process(delta: float) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()

	# Всегда плавно поворачиваемся носом к мыши
	_rotate_toward_mouse(mouse_pos, delta)

	if Input.is_action_pressed("LMB"):
		_move_toward_mouse(mouse_pos, delta)
	else:
		_apply_friction(delta)

	position += _velocity * delta


# ─── Плавный поворот носа к курсору ──────────────────────────────────────────

func _rotate_toward_mouse(mouse_pos: Vector2, delta: float) -> void:
	var target_angle: float = (mouse_pos - global_position).angle()
	rotation = lerp_angle(rotation, target_angle, rotation_speed * delta)


# ─── Движение к позиции мыши ─────────────────────────────────────────────────

func _move_toward_mouse(mouse_pos: Vector2, delta: float) -> void:
	var to_mouse: Vector2 = mouse_pos - global_position
	var distance: float = to_mouse.length()

	# Если уже рядом — тормозим, не дрожим на месте
	if distance < stop_radius:
		_apply_friction(delta)
		return

	# Направление прямо к мыши
	var direction: Vector2 = to_mouse.normalized()

	_velocity += direction * acceleration * delta

	# Ограничиваем максимальной скоростью
	if _velocity.length() > max_speed:
		_velocity = _velocity.normalized() * max_speed


# ─── Плавное торможение (трение) ─────────────────────────────────────────────

func _apply_friction(delta: float) -> void:
	var speed: float = _velocity.length()

	if speed > 0.0:
		var brake: float = min(friction * delta, speed)
		_velocity -= _velocity.normalized() * brake
