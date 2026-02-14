# save_load_slot.gd
extends CanvasLayer

@onready var save_slots_container = $Panel/VBoxContainer/ScrollContainer/SaveSlots
@export var new_save_panel: VBoxContainer
@export var player_name_input: LineEdit
@export var skin_selector: PlayerSkin
@export var create_button: Button
@export var save_slot_template: PackedScene

# Новые переменные для сортировки
#@onready var sort_buttons_container = $Panel/VBoxContainer/HBoxContainer
#@onready var sort_name_button = $Panel/VBoxContainer/HBoxContainer/SortNameButton
#@onready var sort_date_button = $Panel/VBoxContainer/HBoxContainer/SortDateButton

var save_system: SaveSystem
var current_slots = []  # Массив для хранения данных о слотах
var sort_by_name_asc = true  # Сортировка по имени по возрастанию
var sort_by_date_desc = true  # Сортировка по дате по убыванию (новые сверху)

func _ready():
	save_system = SaveSystem.new()
	## Подключаем сигналы кнопок сортировки
	#sort_name_button.pressed.connect(_on_sort_name_pressed)
	#sort_date_button.pressed.connect(_on_sort_date_pressed)
##	
	_sort_slots()
	_display_sorted_slots()
	update_save_slots()
	new_save_panel.visible = false

func update_save_slots():
	# Очищаем текущие слоты
	for child in save_slots_container.get_children():
		child.queue_free()
	
	# Собираем данные о всех слотах
	current_slots.clear()
	var slots = save_system.get_save_slots()
	
	for slot_name in slots:
		var save_path = SaveSystem.SAVE_DIR + slot_name + "/save_data.json"
		
		if not FileAccess.file_exists(save_path):
			push_warning("Save file not found: %s" % save_path)
			continue
			
		var file = FileAccess.open(save_path, FileAccess.READ)
		if not file:
			push_error("Failed to open save file: %s" % save_path)
			continue
		
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result != OK:
			push_error("Failed to parse JSON for save: %s. Error: %s" % [slot_name, json.get_error_message()])
			continue
		
		var save_data = json.get_data()
		if not save_data is Dictionary:
			push_error("Invalid save data format in: %s" % slot_name)
			continue
		
		# Добавляем имя слота в данные
		save_data["slot_name"] = slot_name
		# Добавляем дату последнего сохранения (если есть)
		if not save_data.has("last_save_time"):
			save_data["last_save_time"] = FileAccess.get_modified_time(save_path)
		
		current_slots.append(save_data)
	
	# Сортируем слоты по текущему критерию
	_sort_slots()
	
	# Отображаем отсортированные слоты
	_display_sorted_slots()

func _sort_slots():
	#if sort_name_button.button_pressed:
		## Сортировка по имени игрока
		#current_slots.sort_custom(_sort_by_name)
	#else:
		## Сортировка по дате
	current_slots.sort_custom(_sort_by_date)

func _sort_by_name(a, b):
	var name_a = a.get("player_name", "").to_lower()
	var name_b = b.get("player_name", "").to_lower()
	
	if sort_by_name_asc:
		return name_a < name_b
	else:
		return name_a > name_b

func _sort_by_date(a, b):
	var date_a = a.get("last_save_time", 0)
	var date_b = b.get("last_save_time", 0)
	
	if sort_by_date_desc:
		return date_a > date_b  # Новые сверху
	else:
		return date_a < date_b  # Старые сверху

func _display_sorted_slots():
	# Очищаем контейнер
	for child in save_slots_container.get_children():
		child.queue_free()
	
	# Создаем кнопки для отсортированных слотов
	for save_data in current_slots:
		var slot_button = save_slot_template.instantiate()
		save_slots_container.add_child(slot_button)
		slot_button.setup_slot(save_data)
		slot_button.pressed.connect(_on_save_slot_selected.bind(save_data["slot_name"]))

func _on_save_slot_selected(slot_name: String):
	if save_system.load_save(slot_name):
		Global.day_night.start()
		Global.scene_manager.change_scene("LightGrass", false, Vector2.ZERO)

func _on_new_save_pressed():
	$Panel/VBoxContainer.visible = false
	$ColorRect.visible = true
	new_save_panel.visible = true

func _on_back_pressed() -> void:
	visible = false

func _on_create_pressed() -> void:
	var player_name
	if player_name_input.text != "":
		player_name = player_name_input.text.strip_edges()
	
	if player_name.is_empty() or FileAccess.file_exists("user://Saves/%s/player_data.char" % player_name):
		return
	
	var skin_index = skin_selector.skin_index
	var head_index = skin_selector.head_inex
	
	if save_system.create_new_save(player_name, skin_index, head_index,"LightGrass"):
		update_save_slots()
		new_save_panel.visible = false
		$ColorRect.visible = false
		$Panel/VBoxContainer.visible = true
	else:
		print("Ошибка создания сохранения")

#func _on_sort_name_pressed():
	## Переключаем сортировку по имени
	#sort_name_button.button_pressed = true
	#sort_date_button.button_pressed = false
	#
	## Меняем направление сортировки
	#sort_by_name_asc = !sort_by_name_asc
	#
	## Обновляем иконку кнопки
	#if sort_by_name_asc:
		#sort_name_button.text = "Имя ↑"
	#else:
		#sort_name_button.text = "Имя ↓"
	#
	## Сортируем и обновляем отображение
	#_sort_slots()
	#_display_sorted_slots()
#
#func _on_sort_date_pressed():
	## Переключаем сортировку по дате
	#sort_name_button.button_pressed = false
	#sort_date_button.button_pressed = true
	#
	## Меняем направление сортировки
	#sort_by_date_desc = !sort_by_date_desc
	#
	## Обновляем иконку кнопки
	#if sort_by_date_desc:
		#sort_date_button.text = "Дата ↓"
	#else:
		#sort_date_button.text = "Дата ↑"
	#
	## Сортируем и обновляем отображение
	#_sort_slots()
	#_display_sorted_slots()
