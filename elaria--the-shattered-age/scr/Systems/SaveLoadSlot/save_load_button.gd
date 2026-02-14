# save_load_button.gd
extends Button

@onready var skin: PlayerSkin = $HBoxContainer2/HBoxContainer/TextureRect/Skin

@export var player_name_label: Label
@export var date_label: AutoSizeLabel
@export var textures: Array[Texture2D] = []  # Массив текстур скинов

var slot_name: String = ""  # Будем хранить имя слота здесь

func setup_slot(save_data: Dictionary):
	player_name_label.text = save_data.get("player_name", "Новое сохранение")
	
	var last_save_time = save_data.get("last_save_time", 0)
	if last_save_time > 0:
		var date = Time.get_datetime_dict_from_unix_time(last_save_time)
		date_label.text = "%02d.%02d.%04d %02d:%02d" % [
			date.day, date.month, date.year, date.hour, date.minute
		]
	else:
		date_label.text = "Нет данных"
	
	var skin_index = save_data.get("skin_index", 1)
	var head_index = save_data.get("head_index", 1)
	if skin_index < textures.size():
		skin.skin_index = skin_index
		skin.head_inex = head_index
		skin.update_skin()
	
	# Сохраняем имя слота для последующего удаления
	slot_name = save_data["slot_name"]

func _confirm_delete():
	# Удаляем папку слота
	var dir = DirAccess.open(SaveSystem.SAVE_DIR)
	if dir and dir.dir_exists(slot_name):
		# Рекурсивно удаляем всю папку
		_remove_directory_recursive(SaveSystem.SAVE_DIR + slot_name)
	
	# Обновляем список слотов в главном меню сохранения
	var save_load_slot = get_node("/root").find_child("SaveLoadSlot", true, false)
	if save_load_slot:
		save_load_slot.update_save_slots()
	
	# Удаляем кнопку из интерфейса
	queue_free()

# Вспомогательная функция для рекурсивного удаления папки
func _remove_directory_recursive(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var full_path = path + "/" + file_name
				if dir.current_is_dir():
					_remove_directory_recursive(full_path)
				else:
					dir.remove(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
		dir.remove(path)

# Новый метод — вызывается при нажатии на кнопку "X"
func _on_delete_pressed():
	# Показываем подтверждение удаления (чтобы случайно не удалить)
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Вы уверены, что хотите удалить сохранение \"%s\"?\nЭто действие нельзя отменить!" % player_name_label.text
	confirm.get_ok_button().text = "Удалить"
	confirm.get_cancel_button().text = "Отмена"
	confirm.confirmed.connect(_confirm_delete)
	get_tree().current_scene.add_child(confirm)
	confirm.popup_centered()
