# SaveSystem.gd
extends Node
class_name SaveSystem

const SAVE_DIR = "user://Saves/"
var current_save_slot: String = ""
const SAVE_PATH = "user://Saves/%s/player_data.char"

func get_save_slots() -> Array:
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return []
	
	var save_slots = []
	for file in dir.get_directories():
		if dir.dir_exists(file):
			save_slots.append(file)
	return save_slots

func create_new_save(player_name: String,skin_index: int, head_index : int, location :String) -> bool:
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return false
	
	# Создаем папку с именем игрока (убираем недопустимые символы)
	var safe_player_name = player_name.replace(" ", "_").replace("/", "").replace("\\", "")
	var save_folder = safe_player_name
	
	# Если папка уже существует, добавляем номер
	var counter = 1
	while dir.dir_exists(save_folder):
		save_folder = "%s_%d" % [safe_player_name, counter]
		counter += 1
	
	dir.make_dir(save_folder)
	
	var save_data = {
		"player_name": player_name,
		"head_index": head_index,
		"skin_index": skin_index,
		"location" : location
	}
	
	var file = FileAccess.open(SAVE_DIR + save_folder + "/save_data.json", FileAccess.WRITE)
	if not file:
		return false
	
	file.store_string(JSON.stringify(save_data))
	file.close()
	
	Global.player_name = player_name
	current_save_slot = save_folder
	return true

func load_save(slot_name: String) -> bool:
	var file_path = SAVE_DIR + slot_name + "/save_data.json"
	if not FileAccess.file_exists(file_path):
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		return false
	
	var save_data = json.get_data()
	Global.player_name = save_data.get("player_name", "Player")
	Global.player_skin_index = save_data.get("skin_index", 0)
	Global.player_skin_head_index = save_data.get("head_index", 0)
	Global.current_location = save_data.get("location","Land")
	current_save_slot = slot_name
	return true

static func save_player(player: Node) -> bool:
	var health_bar = player.get_node("HUD/HealthBar")

	var save_data = {
		"stats": {
			"hp":            player.Entity_stats.current_health,
			"max_hp":        player.Entity_stats.max_health,
			"heart_count":   health_bar.heart_count,
			"game_progress": Global.game_progress,
			"location":      Global.current_location,
			"head_index":    player.get_child(5).head_inex,
			"skin_index":    player.get_child(5).skin_index,
		},
		"equipment": {
			"equipped_item": player.get_node("HUD/Inventory/HotBar").selected_index
		},
		"timestamp": Time.get_datetime_string_from_system()
	}

	# Создаем папку сохранения, если не существует
	var dir = DirAccess.open("user://Saves/")
	if not dir.dir_exists(Global.player_name):
		dir.make_dir(Global.player_name)
	
	var file = FileAccess.open(SAVE_PATH % Global.player_name, FileAccess.WRITE)
	if not file:
		push_error("Failed to save player data")
		return false
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return true

static func load_player(player: Node) -> bool:
	var path = SAVE_PATH % Global.player_name
	if not FileAccess.file_exists(path):
		push_warning("No player save file found at: ", path)
		return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open player save file")
		return false
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		push_error("JSON parse error: ", json.get_error_message())
		return false
	
	var save_data = json.get_data()
	if not save_data:
		push_error("Invalid save data format")
		return false
	
	# Загрузка характеристик
	if save_data.has("stats"):
		player.Entity_stats.current_health = save_data.stats.get("hp", player.Entity_stats.max_health)
		player.Entity_stats.max_health = save_data.stats.get("max_hp", player.Entity_stats.max_health)
		Global.current_location = save_data.stats.get("location",Global.current_location)
		Global.game_progress = save_data.stats.get("game_progress",Global.game_progress)
		Global.player_skin_index = save_data.get("skin_index",0)
		Global.player_skin_head_index = save_data.get("head_index", 0)
		player.get_node("HUD/Inventory/HotBar").selected_index = save_data.get("equipped_item",0)
		#Global.player_skin_head_index =  save_data.get("head_index", 0) 
		#Global.player_skin_index =save_data.get("skin_index",0)
		#player.get_node("Skin").skin_index = save_data.get("skin_index",0)
		#player.get_node("Skin").head_inex = save_data.get("head_index", 0) 
		
		# ── Обновляем HealthBar (новая система: 100 HP + heart_count) ──────────
		var health_bar = player.get_node("HUD/HealthBar")

		# Восстанавливаем количество сердец (дефолт 5, если файл старый)
		var saved_hearts: int = save_data.stats.get("heart_count", 5)
		health_bar.heart_count = saved_hearts

		# Переводим реальный HP (0…max_health) в диапазон 0–100 для HealthBar
		var display_hp: float = 100.0
		if player.Entity_stats.max_health > 0:
			display_hp = clampf(
				player.Entity_stats.current_health / player.Entity_stats.max_health * 100.0,
				0.0, 100.0
			)
		health_bar.set_hp(display_hp)

		player.get_node("Skin").update_skin()
		
		print("current location changed " + save_data.stats.get("location",Global.current_location))
		
	return true
