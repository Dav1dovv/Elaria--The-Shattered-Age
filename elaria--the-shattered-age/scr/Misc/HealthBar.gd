@tool
extends Control
class_name HealthBar

## Максимальное значение прогресса
@export var max_value: int = 100 : 
	set(value):
		max_value = max(1, value)
		if Engine.is_editor_hint():
			current_value = max_value
		_update_progress_bar()
		notify_property_list_changed()

## Текущее значение прогресса
@export var current_value: int = 100 : 
	set(value):
		current_value = clamp(value, 0, max_value)
		_update_progress_bar()
		_check_critical_state()

## Размер иконок
@export var icon_size: Vector2 = Vector2(16, 16) : 
	set(value):
		icon_size = value
		_update_progress_bar()

## Расстояние между иконками
@export var icon_spacing: float = 4.0 : 
	set(value):
		icon_spacing = max(0, value)
		_update_progress_bar()

## Количество иконок в ряду (0 для автоматического расчета)
@export var icons_per_row: int = 10 : 
	set(value):
		icons_per_row = max(0, value)
		_update_progress_bar()

## Текстуры для отображения прогресса
@export var full_icon: Texture2D : 
	set(value):
		full_icon = value
		_update_progress_bar()

@export var partial_icon: Texture2D : 
	set(value):
		partial_icon = value
		_update_progress_bar()

@export var empty_icon: Texture2D : 
	set(value):
		empty_icon = value
		_update_progress_bar()

## Количество сегментов на одну иконку (например, 2 для половинок)
@export var segments_per_icon: int = 2 : 
	set(value):
		segments_per_icon = max(1, value)
		_update_progress_bar()

## Направление заполнения прогресса
@export_enum("Left to Right", "Right to Left", "Top to Bottom", "Bottom to Top") 
var fill_direction: int = 0 : 
	set(value):
		fill_direction = value
		_update_progress_bar()

## Выравнивание иконок при неполном ряду
@export_enum("Left", "Center", "Right") 
var row_alignment: int = 0 : 
	set(value):
		row_alignment = value
		_update_progress_bar()

## Пороговое значение для критического состояния (процент от max_value)
@export_range(0, 100) var critical_threshold: float = 20 : 
	set(value):
		critical_threshold = clamp(value, 0, 100)
		_check_critical_state()

## Сила эффекта дёргания (в пикселях)
@export_range(0, 20) var shake_intensity: float = 5 : 
	set(value):
		shake_intensity = clamp(value, 0, 20)

## Скорость дёргания (раз в секунду)
@export_range(0.1, 5.0) var shake_speed: float = 2.0 : 
	set(value):
		shake_speed = clamp(value, 0.1, 5.0)

## Включить/выключить эффект дёргания
@export var shake_enabled: bool = true

## Цвет иконок в нормальном состоянии
@export var normal_color: Color = Color.WHITE : 
	set(value):
		normal_color = value
		_update_icon_colors()

## Цвет иконок в критическом состоянии
@export var critical_color: Color = Color.RED : 
	set(value):
		critical_color = value
		_update_icon_colors()

var _icon_nodes: Array = []
var _is_critical: bool = false
var _shake_timer: float = 0.0
var _original_positions: Array = []

func _ready():
	if not Engine.is_editor_hint():
		current_value = max_value
	_update_progress_bar()

func _process(delta):
	if not shake_enabled or not _is_critical or Engine.is_editor_hint():
		return
	
	_shake_timer += delta * shake_speed
	if _shake_timer >= 1.0:
		_shake_timer = 0.0
	
	# Применяем эффект дёргания к каждой иконке
	for i in range(_icon_nodes.size()):
		var icon = _icon_nodes[i]
		if i >= _original_positions.size():
			continue
		
		if _shake_timer < 0.5:
			# Первая половина анимации - смещаем вправо
			icon.position = _original_positions[i] + Vector2(
				shake_intensity * (0.5 - _shake_timer) / 0.5, 
				randf_range(-shake_intensity/2, shake_intensity/2)
			)
		else:
			# Вторая половина анимации - возвращаем на место
			icon.position = _original_positions[i] + Vector2(
				shake_intensity * (_shake_timer - 0.5) / 0.5, 
				randf_range(-shake_intensity/2, shake_intensity/2)
			)

func _update_progress_bar():
	# Очищаем существующие иконки
	for icon in _icon_nodes:
		icon.queue_free()
	_icon_nodes.clear()
	
	# Проверяем необходимые текстуры
	if not full_icon or not empty_icon:
		push_warning("IconProgressBar: Full and empty icons must be set")
		return
	
	# Рассчитываем количество иконок
	var total_icons = ceil(float(max_value) / segments_per_icon)
	var full_icons = floor(float(current_value) / segments_per_icon)
	var partial_segment = current_value % segments_per_icon
	
	# Рассчитываем количество рядов и столбцов
	var actual_icons_per_row = icons_per_row if icons_per_row > 0 else max(1, floor(size.x / (icon_size.x + icon_spacing)))
	var row_count = ceil(float(total_icons) / actual_icons_per_row)
	
	# Создаем иконки
	for i in range(total_icons):
		var icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = icon_size
		icon.size = icon_size
		
		# Определяем текстуру в зависимости от прогресса
		if i < full_icons:
			icon.texture = full_icon
		elif i == full_icons and partial_segment > 0:
			icon.texture = partial_icon if partial_icon else full_icon
		else:
			icon.texture = empty_icon
		
		# Позиционирование с учетом направления заполнения
		var display_index = _get_display_index(i, total_icons, actual_icons_per_row)
		var row = display_index / actual_icons_per_row
		var col = display_index % actual_icons_per_row
		
		# Выравнивание ряда
		var row_width = min(actual_icons_per_row, total_icons - row * actual_icons_per_row)
		var x_offset = 0
		if row_alignment == 1: # Center
			x_offset = (actual_icons_per_row - row_width) * (icon_size.x + icon_spacing) / 2
		elif row_alignment == 2: # Right
			x_offset = (actual_icons_per_row - row_width) * (icon_size.x + icon_spacing)
		
		var position = Vector2(
			x_offset + col * (icon_size.x + icon_spacing),
			row * (icon_size.y + icon_spacing)
		)
		
		icon.position = position
		add_child(icon)
		_icon_nodes.append(icon)
	
	# Сохраняем оригинальные позиции
	_original_positions = []
	for icon in _icon_nodes:
		_original_positions.append(icon.position)
	
	# Обновляем цвета и проверяем критическое состояние
	_update_icon_colors()
	_check_critical_state()

func _get_display_index(original_index: int, total: int, per_row: int) -> int:
	match fill_direction:
		1: # Right to Left
			var row = original_index / per_row
			var col = original_index % per_row
			return row * per_row + (per_row - 1 - col)
		2: # Top to Bottom
			var col_count = ceil(float(total) / per_row)
			var col = original_index / col_count
			var row = original_index % col_count
			return row * per_row + col
		3: # Bottom to Top
			var col_count = ceil(float(total) / per_row)
			var col = original_index / col_count
			var row = (col_count - 1) - (original_index % col_count)
			return row * per_row + col
		_: # Left to Right (default)
			return original_index

func _check_critical_state():
	var new_critical_state = (float(current_value) / max_value * 100) <= critical_threshold
	if new_critical_state != _is_critical:
		_is_critical = new_critical_state
		_shake_timer = 0.0
		
		if _is_critical:
			# Сохраняем оригинальные позиции при входе в критическое состояние
			_original_positions = []
			for icon in _icon_nodes:
				_original_positions.append(icon.position)
		else:
			# Выход из критического состояния - возвращаем иконки на место
			for i in range(_icon_nodes.size()):
				if i < _original_positions.size():
					_icon_nodes[i].position = _original_positions[i]
		
		_update_icon_colors()

func _update_icon_colors():
	for icon in _icon_nodes:
		if _is_critical:
			icon.modulate = critical_color
		else:
			icon.modulate = normal_color

func set_value(value: int):
	current_value = clamp(value, 0, max_value)
	$Label.text = str(current_value) + "/" + str(max_value)

func increase_value(amount: int):
	set_value(current_value + amount)

func decrease_value(amount: int):
	set_value(current_value - amount)

func set_max_value(value: int):
	max_value = max(1, value)
	current_value = min(current_value, max_value)

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_update_progress_bar()
