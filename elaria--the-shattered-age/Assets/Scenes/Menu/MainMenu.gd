extends ColorRect

# Ссылка на узел Label для сплеш-текста
@onready var splash_label : Label = $CanvasLayer/TextureRect/SplashLabel


# Путь к JSON-файлу с текстами
var splash_json_path = "res://common/SplashTexts.json"
var splash_texts = []

func _ready():
	# Загружаем и парсим JSON
	load_splash_texts()
	# Выбираем случайный сплеш-текст
	set_random_splash_text()
	# Запускаем анимацию
	animate_splash()

func load_splash_texts():
	# Проверяем существование файла
	if FileAccess.file_exists(splash_json_path):
		var file = FileAccess.open(splash_json_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		# Парсим JSON
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var data = json.get_data()
			if data is Array:
				splash_texts = data
			else:
				push_error("JSON root must be an array")
		else:
			push_error("Failed to parse JSON: " + json.get_error_message())
	else:
		push_error("Splash texts JSON file not found at: " + splash_json_path)
		# Запасной массив на случай ошибки
		splash_texts = ["Error loading splash texts!"]

func set_random_splash_text():
	# Выбираем случайный текст из массива
	if splash_texts.size() > 0:
		var random_index = randi() % splash_texts.size()
		splash_label.text = splash_texts[random_index]
	else:
		splash_label.text = "No splash texts available!"

func animate_splash():
	# Создаем твин для анимации
	var tween = create_tween()
	# Начальный масштаб немного меньше
	splash_label.scale = Vector2(0.8, 0.8)
	# Анимация увеличения и уменьшения
	tween.tween_property(splash_label, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(splash_label, "scale", Vector2(0.9, 0.9), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Зацикливаем анимацию
	tween.set_loops()


func _on_options_pressed() -> void:
	#OptionsLayer.visible = true
	pass

func _on_exit_pressed() -> void:
	$CanvasLayer/ConfirmationDialog.visible = true


func _on_confirmation_dialog_confirmed() -> void:
	get_tree().quit()


func _on_confirmation_dialog_canceled() -> void:
	$CanvasLayer/ConfirmationDialog.visible = false


func _on_start_game_pressed() -> void:
	$SaveLoadUI.visible = true


func _on_authors_pressed() -> void:
	pass # Replace with function body.
