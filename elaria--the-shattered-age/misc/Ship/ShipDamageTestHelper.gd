extends Node
class_name ship_damage_test_helper
# ═════════════════════════════════════════════════════════════════════════════
#  ПРИМЕР ТЕСТИРОВАНИЯ УРОНА
# ═════════════════════════════════════════════════════════════════════════════
#
# Прикрепи этот скрипт к WorldController или любому узлу, чтобы протестировать
# систему здоровья корабля через горячие клавиши.
#
# Горячие клавиши:
# - [1] — Нанести 10 урона
# - [2] — Нанести 25 урона
# - [3] — Восстановить 20 здоровья
# - [0] — Полностью восстановить здоровье
#
# ═════════════════════════════════════════════════════════════════════════════

@export var ship_path: NodePath = ^"Ship"  # Путь к кораблю
var ship: Node = null


func _ready() -> void:
	ship = get_node_or_null(ship_path)
	if not ship:
		print("DamageTest: Корабль не найден по пути ", ship_path)


func _input(event: InputEvent) -> void:
	if not ship or not ship.has_method("take_damage"):
		return
	
	# Тест урона и лечения
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				ship.take_damage(10.0)
				print("DamageTest: Нанесено 10 урона")
			
			KEY_2:
				ship.take_damage(25.0)
				print("DamageTest: Нанесено 25 урона")
			
			KEY_3:
				ship.heal(20.0)
				print("DamageTest: Восстановлено 20 здоровья")
			
			KEY_0:
				ship.current_health = ship.max_health
				ship.emit_signal("health_changed", ship.current_health, ship.max_health)
				print("DamageTest: Здоровье полностью восстановлено")
