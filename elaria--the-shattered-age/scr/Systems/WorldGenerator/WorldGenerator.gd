@tool
extends Node2D
class_name WorldGenerator

@export var generation_items: Array[Generation]
@export var zones: Array[GenerationZone]
@export_range(0.0, 1.0) var object_spawn_chance: float = 0.4
@export var generate_on_start: bool = true
@export var location_id: String = "default_location"  # Уникальный идентификатор локации
@export var min_distance_between_objects: float = 50.0  # Минимальное расстояние между объектами
@export var max_cluster_size: int = 5  # Максимум объектов в кластере
@export var cluster_radius: float = 100.0  # Радиус кластера
@export var max_cluster_attempts: int = 10  # Максимум попыток размещения точки в кластере

@export_category("Special Structures")
@export var special_structures: Array[SpecialStructure] = []  # Специальные структуры (лагери, данжи)
@export var max_structure_placement_attempts: int = 100  # Максимум попыток размещения структуры

@export_category("Generation Settings")
@export var player: Node2D
@export var spawn_area_size: Vector2 = Vector2(1000, 1000):
	set(value):
		spawn_area_size = value
		if Engine.is_editor_hint():
			update_configuration_warnings()
			queue_redraw()
@export var player_clear_radius: float = 300.0
@export var noise_scale: float = 0.005  # Масштаб шума для зон
@export var noise_octaves: int = 3  # Количество октав шума

@export_category("Generation Mode")
enum GenerationMode {
	CENTERED_ON_PLAYER,     # Центр области = позиция игрока
	WORLD_ORIGIN,           # Центр области = (0, 0)
	RANDOM_OFFSET,          # Случайное смещение от игрока
	CUSTOM_POSITION,        # Пользовательская позиция
	FIXED_GRID              # Фиксированная сетка областей
}
@export var generation_mode: GenerationMode = GenerationMode.CENTERED_ON_PLAYER
@export var custom_center_position: Vector2 = Vector2.ZERO  # Для CUSTOM_POSITION
@export var random_offset_range: Vector2 = Vector2(500, 500)  # Для RANDOM_OFFSET
@export var grid_cell_size: Vector2 = Vector2(2000, 2000)  # Для FIXED_GRID
@export var grid_cells_to_generate: int = 9  # Количество ячеек сетки для генерации

var seed_encryption: int
var location_seed: int  # Сид этой конкретной локации
var noise: FastNoiseLite

# Трекинг специальных структур
var placed_special_structures: Array[Dictionary] = []  # {position: Vector2, structure: SpecialStructure, instance: Node2D}
var structure_type_counts: Dictionary = {}  # StructureType -> int

func _init() -> void:
	_initialize_noise()

func _initialize_noise() -> void:
	if not noise:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.fractal_octaves = noise_octaves
		noise.frequency = noise_scale
		
		# Получаем сид из GameManager (родитель должен быть GameManager)
		var game_manager = get_parent()
		if game_manager and game_manager.has_method("get_or_create_location_seed"):
			location_seed = game_manager.get_or_create_location_seed(location_id)
			noise.seed = location_seed
			print("[WorldGenerator '%s'] Using location seed: %d" % [location_id, location_seed])
		else:
			# Fallback: используем случайный сид
			location_seed = randi()
			noise.seed = location_seed
			push_warning("[WorldGenerator '%s'] GameManager not found, using random seed: %d" % [location_id, location_seed])

func _ready() -> void:
	location_id = location_id + Global.player_name
	if Engine.is_editor_hint():
		return
	
	# Получаем сид из GameManager
	var game_manager = get_parent()
	if game_manager and game_manager.has_method("get_or_create_location_seed"):
		location_seed = game_manager.get_or_create_location_seed(location_id)
		seed_encryption = location_seed
		seed(location_seed)
		_initialize_noise()
		print("[WorldGenerator '%s'] Initialized with location seed: %d" % [location_id, location_seed])
	else:
		# Fallback: случайная генерация
		randomize()
		location_seed = randi()
		seed_encryption = location_seed
		_initialize_noise()
		push_warning("[WorldGenerator '%s'] GameManager not found, using random seed" % location_id)
	
	if generate_on_start:
		_generate()

func _generate():
	if Engine.is_editor_hint():
		return

	if not noise:
		push_error("Noise is not initialized! Initializing now...")
		_initialize_noise()

	# Очищаем трекинг
	placed_special_structures.clear()
	structure_type_counts.clear()

	var spawn_bounds = get_spawn_bounds()
	var spawned_positions: Array[Vector2] = []

	# Для режима FIXED_GRID генерируем несколько областей
	if generation_mode == GenerationMode.FIXED_GRID:
		_generate_grid_areas(spawned_positions)
	else:
		_generate_single_area(spawn_bounds, spawned_positions)
	
	get_tree().paused = true
	await get_tree().create_timer(1).timeout
	get_tree().paused = false

func _generate_single_area(spawn_bounds: Rect2, spawned_positions: Array[Vector2]):
	# Сначала генерируем специальные структуры
	_generate_special_structures(spawn_bounds)
	
	# Затем генерируем обычные объекты
	var points = _generate_poisson_points(spawn_bounds)
	for spawn_pos in points:
		# Проверяем расстояние до игрока
		if player and is_instance_valid(player):
			if spawn_pos.distance_to(player.global_position) < player_clear_radius:
				continue

		# Проверяем, не в зоне исключения ли специальной структуры
		if _is_in_structure_exclusion_zone(spawn_pos):
			continue

		# Проверяем минимальное расстояние до других объектов
		var too_close = false
		for existing_pos in spawned_positions:
			if spawn_pos.distance_to(existing_pos) < min_distance_between_objects:
				too_close = true
				break
		if too_close:
			continue

		# Генерируем кластер
		var cluster_size = randi_range(1, max_cluster_size) if randf() < object_spawn_chance else 1
		var cluster_points = _generate_cluster_points(spawn_pos, cluster_size, spawned_positions)

		for cluster_pos in cluster_points:
			if not spawn_bounds.has_point(cluster_pos):
				continue
			
			# Проверяем еще раз для каждой точки кластера
			if _is_in_structure_exclusion_zone(cluster_pos):
				continue

			# Определяем зону на основе шума
			var noise_value = (noise.get_noise_2d(cluster_pos.x, cluster_pos.y) + 1) / 2
			var selected_item = _select_generation_item(noise_value, cluster_pos)
			if not selected_item:
				continue

			# Создаем объект
			var scene = _get_random_scene(selected_item)
			if scene:
				var instance = scene.instantiate()
				instance.global_position = cluster_pos

				var scale_key = selected_item.random_scales.keys()[randi() % selected_item.random_scales.size()]
				instance.scale = selected_item.random_scales[scale_key]

				if selected_item.random_rotation_degress > 0:
					instance.rotation_degrees = randf_range(-selected_item.random_rotation_degress, selected_item.random_rotation_degress)

				call_deferred("add_child",instance)
				spawned_positions.append(cluster_pos)

func _generate_special_structures(spawn_bounds: Rect2) -> void:
	if special_structures.is_empty():
		return
	
	# Сортируем структуры по приоритету (выше приоритет = раньше генерируется)
	var sorted_structures = special_structures.duplicate()
	sorted_structures.sort_custom(func(a, b): return a.spawn_priority > b.spawn_priority)
	
	for structure in sorted_structures:
		if not structure.generation_item:
			continue
		
		# Проверяем шанс появления
		if randf() > structure.spawn_chance:
			continue
		
		# Определяем количество для генерации
		var instances_to_create = structure.max_instances
		var created_count = 0
		
		# Пытаемся разместить структуры
		for _attempt in range(max_structure_placement_attempts):
			if created_count >= instances_to_create:
				break
			
			# Генерируем случайную позицию
			var pos = spawn_bounds.position + Vector2(
				randf() * spawn_bounds.size.x,
				randf() * spawn_bounds.size.y
			)
			
			# Проверяем все условия размещения
			if not _can_place_structure(structure, pos):
				continue
			
			# Создаем структуру
			var scene = _get_random_scene(structure.generation_item)
			if scene:
				var instance = scene.instantiate()
				instance.global_position = pos
				
				# Применяем трансформации
				if not structure.generation_item.random_scales.is_empty():
					var scale_key = structure.generation_item.random_scales.keys()[randi() % structure.generation_item.random_scales.size()]
					instance.scale = structure.generation_item.random_scales[scale_key]
				
				if structure.generation_item.random_rotation_degress > 0:
					instance.rotation_degrees = randf_range(-structure.generation_item.random_rotation_degress, structure.generation_item.random_rotation_degress)
				
				call_deferred("add_child", instance)
				
				# Сохраняем информацию о структуре
				placed_special_structures.append({
					"position": pos,
					"structure": structure,
					"instance": instance
				})
				
				# Обновляем счетчик типов
				var type_key = structure.structure_type
				if structure_type_counts.has(type_key):
					structure_type_counts[type_key] += 1
				else:
					structure_type_counts[type_key] = 1
				
				created_count += 1
				
				print("Placed %s at %s (%d/%d)" % [structure.structure_name, pos, created_count, instances_to_create])

func _can_place_structure(structure: SpecialStructure, pos: Vector2) -> bool:
	# Проверка расстояния от игрока
	if player and is_instance_valid(player):
		if pos.distance_to(player.global_position) < structure.min_distance_from_player:
			return false
	
	# Проверка расстояний до других структур
	for placed in placed_special_structures:
		var placed_pos = placed["position"]
		var placed_structure = placed["structure"]
		var distance = pos.distance_to(placed_pos)
		
		# Проверка минимального расстояния до любых структур
		if distance < structure.min_distance_between_any:
			return false
		
		# Проверка минимального расстояния до структур того же типа
		if placed_structure.structure_type == structure.structure_type:
			if distance < structure.min_distance_between_same_type:
				return false
	
	return true

func _is_in_structure_exclusion_zone(pos: Vector2) -> bool:
	for placed in placed_special_structures:
		var placed_pos = placed["position"]
		var placed_structure = placed["structure"]
		if pos.distance_to(placed_pos) < placed_structure.exclusion_radius:
			return true
	return false

func _generate_grid_areas(spawned_positions: Array[Vector2]):
	# Определяем центральную ячейку на основе позиции игрока
	var player_pos = player.global_position if (player and is_instance_valid(player)) else Vector2.ZERO
	var center_cell_x = int(player_pos.x / grid_cell_size.x)
	var center_cell_y = int(player_pos.y / grid_cell_size.y)
	
	# Вычисляем размер сетки (например, 3x3 для 9 ячеек)
	var grid_side = int(sqrt(grid_cells_to_generate))
	var half_grid = grid_side / 2
	
	# Генерируем каждую ячейку сетки
	for cell_x in range(center_cell_x - half_grid, center_cell_x + half_grid + 1):
		for cell_y in range(center_cell_y - half_grid, center_cell_y + half_grid + 1):
			var cell_bounds = Rect2(
				Vector2(cell_x * grid_cell_size.x, cell_y * grid_cell_size.y),
				grid_cell_size
			)
			_generate_single_area(cell_bounds, spawned_positions)

func _generate_poisson_points(bounds: Rect2) -> Array:
	var points: Array[Vector2] = []
	var active: Array[Vector2] = []
	var cell_size = min_distance_between_objects / sqrt(2)
	var grid_width = int(bounds.size.x / cell_size) + 1
	var grid_height = int(bounds.size.y / cell_size) + 1
	var grid: Array = []
	grid.resize(grid_width * grid_height)

	# Начальная случайная точка
	var start_pos = bounds.position + bounds.size * Vector2(randf(), randf())
	points.append(start_pos)
	active.append(start_pos)
	_set_grid_point(grid, grid_width, cell_size, bounds, start_pos)

	# Генерация точек
	while active.size() > 0:
		var idx = randi() % active.size()
		var point = active[idx]
		var found = false

		for _i in range(30):
			var angle = randf() * TAU
			var radius = randf_range(min_distance_between_objects, 2 * min_distance_between_objects)
			var new_point = point + Vector2(cos(angle), sin(angle)) * radius

			if not bounds.has_point(new_point):
				continue

			if _is_valid_point(grid, grid_width, cell_size, bounds, new_point):
				points.append(new_point)
				active.append(new_point)
				_set_grid_point(grid, grid_width, cell_size, bounds, new_point)
				found = true
				break

		if not found:
			active.remove_at(idx)

	return points

func _set_grid_point(grid: Array, grid_width: int, cell_size: float, bounds: Rect2, point: Vector2):
	var grid_x = int((point.x - bounds.position.x) / cell_size)
	var grid_y = int((point.y - bounds.position.y) / cell_size)
	if grid_x >= 0 and grid_x < grid_width and grid_y >= 0 and grid_y < grid.size() / grid_width:
		grid[grid_y * grid_width + grid_x] = point

func _is_valid_point(grid: Array, grid_width: int, cell_size: float, bounds: Rect2, point: Vector2) -> bool:
	var grid_x = int((point.x - bounds.position.x) / cell_size)
	var grid_y = int((point.y - bounds.position.y) / cell_size)

	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = grid_x + dx
			var ny = grid_y + dy
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid.size() / grid_width:
				var neighbor = grid[ny * grid_width + nx]
				if neighbor != null and point.distance_to(neighbor) < min_distance_between_objects:
					return false
	return true

func _generate_cluster_points(center: Vector2, size: int, existing_positions: Array[Vector2]) -> Array:
	var points: Array[Vector2] = [center]
	var cluster_points: Array[Vector2] = [center]

	for _i in range(size - 1):
		var attempts = 0
		var placed = false

		while attempts < max_cluster_attempts:
			var angle = randf() * TAU
			var radius = randf_range(0, cluster_radius)
			var new_point = center + Vector2(cos(angle), sin(angle)) * radius

			# Проверяем, не перекрывается ли новая точка с существующими
			var too_close = false
			for existing_pos in existing_positions:
				if new_point.distance_to(existing_pos) < min_distance_between_objects:
					too_close = true
					break
			for cluster_pos in cluster_points:
				if new_point.distance_to(cluster_pos) < min_distance_between_objects:
					too_close = true
					break

			if not too_close:
				cluster_points.append(new_point)
				placed = true
				break

			attempts += 1

		if not placed:
			break  # Прерываем, если не удалось разместить точку

	return cluster_points

func _select_generation_item(noise_value: float, position: Vector2) -> Generation:
	var weighted_items: Array[Generation] = []
	var weights: Array[float] = []

	for item in generation_items:
		weighted_items.append(item)
		weights.append(item.spawn_weight)

	for zone in zones:
		if noise_value >= zone.noise_threshold:
			for item in zone.dominant_items:
				var idx = weighted_items.find(item)
				if idx != -1:
					weights[idx] *= zone.spawn_weight_multiplier

	var total_weight = 0.0
	for weight in weights:
		total_weight += weight

	if total_weight == 0:
		return null

	var random_value = randf() * total_weight
	var current_weight = 0.0

	for i in range(weighted_items.size()):
		current_weight += weights[i]
		if random_value <= current_weight:
			return weighted_items[i]
	return null

func _get_random_scene(generation: Generation) -> PackedScene:
	var scenes = [generation.Generation_scene]
	if not generation.Generation_random_versions.is_empty():
		scenes.append_array(generation.Generation_random_versions)
	return scenes[randi() % scenes.size()]

func _draw() -> void:
	if Engine.is_editor_hint():
		var bounds = get_spawn_bounds()
		draw_rect(Rect2(bounds.position - global_position, bounds.size), Color(0, 1, 0, 0.2), true)
		draw_rect(Rect2(bounds.position - global_position, bounds.size), Color(0, 1, 0, 0.5), false, 2.0)
		if noise:
			for x in range(int(bounds.position.x), int(bounds.position.x + bounds.size.x), 50):
				for y in range(int(bounds.position.y), int(bounds.position.y + bounds.size.y), 50):
					var noise_value = (noise.get_noise_2d(x, y) + 1) / 2
					var color = Color(0, 0, 0, 0.1)
					for zone in zones:
						if noise_value >= zone.noise_threshold:
							color = Color(randf(), randf(), randf(), 0.1)
							break
					draw_rect(Rect2(Vector2(x, y) - global_position, Vector2(50, 50)), color, true)

func get_spawn_bounds() -> Rect2:
	var center_pos: Vector2
	var half_size = spawn_area_size * 0.5
	
	match generation_mode:
		GenerationMode.CENTERED_ON_PLAYER:
			# Оригинальный режим - центр на игроке
			if not player or not is_instance_valid(player):
				center_pos = Vector2.ZERO
			else:
				center_pos = player.global_position
		
		GenerationMode.WORLD_ORIGIN:
			# Генерация вокруг точки (0, 0)
			center_pos = Vector2.ZERO
		
		GenerationMode.RANDOM_OFFSET:
			# Случайное смещение от игрока (или от 0,0 если игрока нет)
			var base_pos = player.global_position if (player and is_instance_valid(player)) else Vector2.ZERO
			var random_x = randf_range(-random_offset_range.x, random_offset_range.x)
			var random_y = randf_range(-random_offset_range.y, random_offset_range.y)
			center_pos = base_pos + Vector2(random_x, random_y)
		
		GenerationMode.CUSTOM_POSITION:
			# Фиксированная пользовательская позиция
			center_pos = custom_center_position
		
		GenerationMode.FIXED_GRID:
			# Для сетки возвращаем область вокруг игрока
			# (фактическая генерация происходит в _generate_grid_areas)
			if not player or not is_instance_valid(player):
				center_pos = Vector2.ZERO
			else:
				center_pos = player.global_position
	
	return Rect2(center_pos - half_size, spawn_area_size)

## Публичные методы для доступа к информации о структурах

func get_placed_structures() -> Array[Dictionary]:
	"""Возвращает массив всех размещенных специальных структур"""
	return placed_special_structures

func get_structures_by_type(type: SpecialStructure.StructureType) -> Array[Dictionary]:
	"""Возвращает массив структур определенного типа"""
	var result: Array[Dictionary] = []
	for placed in placed_special_structures:
		if placed["structure"].structure_type == type:
			result.append(placed)
	return result

func get_nearest_structure(position: Vector2, type: SpecialStructure.StructureType = -1) -> Dictionary:
	"""Возвращает ближайшую структуру к заданной позиции (опционально определенного типа)"""
	var nearest: Dictionary = {}
	var min_distance = INF
	
	for placed in placed_special_structures:
		if type != -1 and placed["structure"].structure_type != type:
			continue
		
		var distance = position.distance_to(placed["position"])
		if distance < min_distance:
			min_distance = distance
			nearest = placed
	
	return nearest
