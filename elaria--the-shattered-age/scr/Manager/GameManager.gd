extends Node2D

@export var world_seed: String

var last_saved_position: Array[Vector2]
var player

func _ready() -> void:
	world_seed = Global.player_name
	add_to_group("World")
	_initialize_seed_system()
	
func respawn():
	player = get_tree().get_first_node_in_group("Player")
	player.position = last_saved_position.front()

func set_spawn_point(save_position : Vector2):
	last_saved_position.append(save_position)
	print("Player saved at: "+ str(save_position))

#region SEED SYStTEM
# Главный сид мира
var master_seed: int = 0

# Словарь всех сидов локаций: {"location_id": seed_value}
var location_seeds: Dictionary = {}

# Функция для получения пути к файлу сидов
func get_world_seeds_path() -> String:
	if not Global or Global.player_name.is_empty():
		push_warning("[GameManager] Player name is empty, using default path")
		return "user://world_seeds.json"
	
	var player_dir = Global.player_name.replace(" ", "_")
	return "user://Saves/%s/worldsave/world_seeds.json" % player_dir



# Инициализация системы сидов
func _initialize_seed_system() -> void:
	# Создаём директорию worldsave если её нет
	_ensure_worldsave_directory()
	
	if not world_seed.is_empty():
		# Используем заданный сид
		master_seed = world_seed.hash()
	else:
		# Генерируем случайный сид
		randomize()
		master_seed = randi()
		world_seed = str(master_seed)
	
	print("[GameManager] Master seed initialized: %d (from: '%s')" % [master_seed, world_seed])
	
	# Пытаемся загрузить существующие сиды локаций
	_load_location_seeds()

# Создание директории worldsave
func _ensure_worldsave_directory() -> void:
	if not Global or Global.player_name.is_empty():
		push_warning("[GameManager] Cannot create worldsave directory - player name is empty")
		return
	
	var player_dir = Global.player_name.replace(" ", "_")
	var saves_dir = "user://Saves/%s" % player_dir
	var worldsave_dir = "%s/worldsave" % saves_dir
	
	var dir = DirAccess.open("user://")
	if dir:
		# Создаём Saves если нет
		if not dir.dir_exists("Saves"):
			dir.make_dir("Saves")
		
		# Создаём папку игрока если нет
		if not dir.dir_exists(saves_dir):
			dir.make_dir_recursive(saves_dir)
		
		# Создаём папку worldsave если нет
		if not dir.dir_exists(worldsave_dir):
			dir.make_dir_recursive(worldsave_dir)
			print("[GameManager] Created worldsave directory: %s" % worldsave_dir)
	else:
		push_error("[GameManager] Failed to access user:// directory")
# ========== МЕТОДЫ РАБОТЫ С СИДАМИ ЛОКАЦИЙ ==========

# Получить или создать сид для локации
func get_or_create_location_seed(location_id: String) -> int:
	# Если сид уже существует, возвращаем его
	if location_seeds.has(location_id):
		var existing_seed = location_seeds[location_id]
		print("[GameManager] Using existing seed for '%s': %d" % [location_id, existing_seed])
		return existing_seed
	
	# Создаём новый уникальный сид для локации
	var new_seed = _generate_location_seed(location_id)
	location_seeds[location_id] = new_seed
	
	print("[GameManager] Generated new seed for '%s': %d" % [location_id, new_seed])
	
	# Сохраняем обновлённый список сидов
	_save_location_seeds()
	
	return new_seed

# Генерация уникального сида для локации
func _generate_location_seed(location_id: String) -> int:
	# Комбинируем главный сид с ID локации для уникальности
	var combined_string = str(master_seed) + "_" + location_id
	return combined_string.hash()

# Установить конкретный сид для локации (для отладки/читов)
func set_location_seed(location_id: String, seed_value: int) -> void:
	location_seeds[location_id] = seed_value
	_save_location_seeds()
	print("[GameManager] Set seed for '%s': %d" % [location_id, seed_value])

# Получить все сиды локаций
func get_all_location_seeds() -> Dictionary:
	return location_seeds.duplicate()

# Сброс сида конкретной локации (для регенерации)
func reset_location_seed(location_id: String) -> void:
	if location_seeds.has(location_id):
		location_seeds.erase(location_id)
		_save_location_seeds()
		print("[GameManager] Reset seed for '%s'" % location_id)

# Сброс всех сидов локаций
func reset_all_location_seeds() -> void:
	location_seeds.clear()
	_save_location_seeds()
	print("[GameManager] All location seeds reset")

# ========== СОХРАНЕНИЕ И ЗАГРУЗКА СИДОВ ==========

# Сохранение сидов в файл
func _save_location_seeds() -> void:
	var file_path = get_world_seeds_path()
	
	# Убеждаемся что директория существует
	_ensure_worldsave_directory()
	
	var save_data = {
		"master_seed": master_seed,
		"world_seed": world_seed,
		"location_seeds": location_seeds,
		"player_name": Global.player_name if Global else "Unknown",
		"version": "1.0"
	}
	
	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		print("[GameManager] Location seeds saved to: %s" % file_path)
	else:
		push_error("[GameManager] Failed to save location seeds to: %s" % file_path)

# Загрузка сидов из файла
func _load_location_seeds() -> void:
	var file_path = get_world_seeds_path()
	
	if not FileAccess.file_exists(file_path):
		print("[GameManager] No saved location seeds found at: %s" % file_path)
		print("[GameManager] Starting with fresh world seeds")
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[GameManager] Failed to load location seeds from: %s" % file_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("[GameManager] Failed to parse location seeds JSON!")
		return
	
	var save_data = json.data
	
	# Загружаем данные
	if save_data.has("master_seed"):
		var saved_master_seed = save_data["master_seed"]
		
		# Проверяем, совпадает ли сохранённый мастер-сид с текущим
		if saved_master_seed != master_seed:
			push_warning("[GameManager] Master seed mismatch! Saved: %d, Current: %d" % [saved_master_seed, master_seed])
			push_warning("[GameManager] This may result in different world generation.")
	
	if save_data.has("location_seeds"):
		location_seeds = save_data["location_seeds"]
		print("[GameManager] Loaded %d location seeds from: %s" % [location_seeds.size(), file_path])
	
	# Выводим все загруженные сиды
	if location_seeds.size() > 0:
		print("[GameManager] Location seeds:")
		for loc_id in location_seeds.keys():
			print("  - '%s': %d" % [loc_id, location_seeds[loc_id]])

# Экспорт сидов в читаемом формате (для шаринга сидов между игроками)
func export_world_seed_string() -> String:
	var export_data = {
		"world_seed": world_seed,
		"master_seed": master_seed
	}
	return JSON.stringify(export_data)

# Импорт мастер-сида из строки
func import_world_seed(seed_string: String) -> bool:
	var json = JSON.new()
	var parse_result = json.parse(seed_string)
	
	if parse_result != OK:
		push_error("[GameManager] Invalid seed string!")
		return false
	
	var data = json.data
	if data.has("world_seed"):
		world_seed = data["world_seed"]
		master_seed = world_seed.hash() if world_seed is String else data.get("master_seed", 0)
		
		# Очищаем старые сиды локаций при импорте нового мира
		reset_all_location_seeds()
		
		print("[GameManager] Imported world seed: '%s' (master: %d)" % [world_seed, master_seed])
		return true
	
	return false
