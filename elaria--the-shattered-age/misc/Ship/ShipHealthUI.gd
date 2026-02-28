extends CanvasLayer
class_name ship_healthUI
# ═════════════════════════════════════════════════════════════════════════════
#  UI ШКАЛЫ ЗДОРОВЬЯ КОРАБЛЯ
# ═════════════════════════════════════════════════════════════════════════════
#
# Инструкция по подключению:
# 1. Создай CanvasLayer узел и прикрепи этот скрипт
# 2. Добавь дочерние узлы:
#    - Control (для позиционирования)
#      - ProgressBar (назови "HealthBar")
# 3. В WorldController/сцене найди корабль и подключи сигналы:
#    ship.health_changed.connect($HealthUI._on_health_changed)
#
# ═════════════════════════════════════════════════════════════════════════════

@onready var health_bar: ProgressBar = $Control/ProgHealthBar

@export var ship_path: NodePath  # Путь к кораблю (можно задать в инспекторе)


func _ready() -> void:
	# Автоматическое подключение к кораблю, если путь задан
	if not ship_path.is_empty():
		var ship = get_node_or_null(ship_path)
		if ship:
			ship.health_changed.connect(_on_health_changed)
			ship.ship_destroyed.connect(_on_ship_destroyed)
		else:
			print("HealthUI: корабль не найден по пути ", ship_path)


# ─── Обновление шкалы здоровья ───────────────────────────────────────────────

func _on_health_changed(current: float, maximum: float) -> void:
	if not health_bar:
		return
	
	health_bar.max_value = maximum
	health_bar.value = current
	
	# Меняем цвет в зависимости от здоровья
	_update_health_bar_color(current, maximum)


func _update_health_bar_color(current: float, maximum: float) -> void:
	if not health_bar:
		return
	
	var health_percent := current / maximum
	
	# Создаём StyleBox для изменения цвета
	var style := StyleBoxFlat.new()
	
	if health_percent > 0.6:
		style.bg_color = Color(0.2, 0.8, 0.2)  # Зелёный
	elif health_percent > 0.3:
		style.bg_color = Color(0.9, 0.7, 0.2)  # Жёлтый
	else:
		style.bg_color = Color(0.9, 0.2, 0.2)  # Красный
	
	health_bar.add_theme_stylebox_override("fill", style)


# ─── Когда корабль уничтожен ─────────────────────────────────────────────────

func _on_ship_destroyed() -> void:
	if health_bar:
		health_bar.value = 0
	
	# Можно показать экран "Game Over" или другую реакцию
	print("HealthUI: Корабль уничтожен!")


# ═════════════════════════════════════════════════════════════════════════════
#  АЛЬТЕРНАТИВА: Подключение вручную из кода
# ═════════════════════════════════════════════════════════════════════════════
# Если не хочешь задавать NodePath, можешь вызвать эту функцию из WorldController:
#
# func connect_to_ship(ship: Node) -> void:
#     ship.health_changed.connect(_on_health_changed)
#     ship.ship_destroyed.connect(_on_ship_destroyed)
