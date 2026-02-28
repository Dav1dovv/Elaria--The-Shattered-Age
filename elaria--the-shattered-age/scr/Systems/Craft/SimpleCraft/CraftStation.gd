extends Control

@onready var search_box: LineEdit = $Panel/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/LineEdit
@onready var category_filter: OptionButton = $Panel/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/OptionButton
@onready var recipe_grid: GridContainer = $Panel/MarginContainer/HBoxContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var result_slot: InventorySlot = $Panel/MarginContainer/HBoxContainer/VBoxContainer2/Label/ResultSlot
@onready var ingredients_list: GridContainer = $Panel/MarginContainer/HBoxContainer/VBoxContainer2/ScrollContainer/VBoxContainer
@onready var craft_button: Button = $Panel/MarginContainer/HBoxContainer/VBoxContainer2/Button
@onready var progress_bar: ProgressBar = $Panel/MarginContainer/HBoxContainer/VBoxContainer2/Button/ProgressBar
@onready var craft_max_button: Button = $Panel/MarginContainer/HBoxContainer/VBoxContainer2/Label/ResultSlot/MaxCount

@export var all_recipes: Array[CraftRecipe] = []
var filtered_recipes: Array[CraftRecipe] = []
var selected_recipe: CraftRecipe = null
var inventory: Inventory = null
var is_crafting := false

func _ready() -> void:
	inventory = get_tree().get_first_node_in_group("Inventory")
	var hotbar = get_tree().get_first_node_in_group("Hotbar")
	
	if inventory:
		inventory.inventory_changed.connect(_refresh)
	if hotbar:
		hotbar.hotbar_changed.connect(_refresh)
	
	 #Загружаем все рецепты из папки
	_load_all_recipes()
	_setup_categories()
	_refresh()

	search_box.text_changed.connect(_on_search_changed)
	category_filter.item_selected.connect(_on_category_changed)
	#recipe_grid.item_selected.connect(_on_recipe_selected)
	craft_button.pressed.connect(_on_craft_pressed)
	craft_max_button.pressed.connect(_on_craft_max_pressed)

func _load_all_recipes() -> void:
	var dir = DirAccess.open("res://scr/Resources/Recipes/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var recipe = load("res://scr/Resources/Recipes/" + file_name)
				if recipe is CraftRecipe:
					all_recipes.append(recipe)
			file_name = dir.get_next()
	_refresh()

func _setup_categories() -> void:
	category_filter.add_item("Все", 0)
	category_filter.add_item("Оружие", 1)
	category_filter.add_item("Еда", 2)
	category_filter.add_item("Материалы", 3)
	category_filter.add_item("Аксессуары", 4)

func _refresh() -> void:
	var search_text = search_box.text.to_lower()
	var category_id = category_filter.selected
	
	filtered_recipes.clear()
	for recipe in all_recipes:
		var matches_search = search_text.is_empty() or recipe.recipe_name.to_lower().contains(search_text)
		var matches_category = category_id == 0 or _get_recipe_category(recipe) == category_id
		if matches_search and matches_category:
			filtered_recipes.append(recipe)
	
	_update_recipe_list()

func _get_recipe_category(recipe: CraftRecipe) -> int:
	if recipe.result_item is equip_data:
		return 1
	if recipe.result_item is FoodData:
		return 2
	if recipe.result_item is AccessoryData:
		return 4
	return 3  # Материалы

func _update_recipe_list() -> void:
	# Очищаем старые кнопки
	for child in recipe_grid.get_children():
		child.queue_free()
	
	for recipe in filtered_recipes:
		var button = TextureButton.new()
		button.custom_minimum_size = Vector2(16, 16)
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.ignore_texture_size = true
		
		# Фон (опционально — рамка)
		var panel = Panel.new()
		panel.size = button.custom_minimum_size
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(panel)
		
		# Иконка предмета
		var icon = TextureRect.new()
		icon.texture = recipe.result_item.icon
		icon.custom_minimum_size = Vector2(16, 16)
		icon.position = Vector2(0, 0)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		button.add_child(icon)
		
		## Название
		var name_label = Label.new()
		name_label.text = recipe.recipe_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_label.position = Vector2(-20, 18)
		name_label.size = Vector2(64, 20)
		name_label.add_theme_font_size_override("font_size", 4)
		name_label.clip_text = true
		button.add_child(name_label)
		
		# Можно ли крафтить
		var can_craft = recipe.can_craft(inventory)
		if not can_craft:
			button.modulate = Color(0.6, 0.6, 0.6, 0.8)
		
		# Подсказка
		button.tooltip_text = recipe.description
		
		# Подключаем клик
		button.pressed.connect(func():
			selected_recipe = recipe
			_update_preview()
		)
		
		recipe_grid.add_child(button)

func _on_search_changed(new_text: String) -> void:
	_refresh()

func _on_category_changed(index: int) -> void:
	_refresh()

func _on_recipe_selected(index: int) -> void:
	selected_recipe = filtered_recipes[index]
	_update_preview()

func _update_preview() -> void:
	for child in ingredients_list.get_children():
		child.queue_free()
	
	if not selected_recipe:
		result_slot.item = null
		result_slot.update_ui()
		return
	
	result_slot.item = selected_recipe.result_item
	result_slot.ammount = selected_recipe.result_amount
	result_slot.update_ui()
	
	for ing in selected_recipe.ingredients:
		var hbox = HBoxContainer.new()
		var icon = TextureRect.new()
		icon.texture = ing.item.icon
		icon.custom_minimum_size = Vector2(18, 18)
		
		var label = Label.new()
		var have = inventory.get_total_item_count(ing.item)
		label.text = "%d / %d" % [have, ing.amount]
		label.add_theme_font_size_override("font_size", 8)
		label.modulate = Color.GREEN if have >= ing.amount else Color.RED
		
		hbox.add_child(icon)
		hbox.add_child(label)
		ingredients_list.add_child(hbox)
	
	craft_button.disabled = not selected_recipe.can_craft(inventory) or is_crafting

func _on_craft_pressed() -> void:
	if not selected_recipe or is_crafting: return
	if not selected_recipe.can_craft(inventory): return
	
	var timer = get_tree().create_timer(selected_recipe.crafting_time)
	timer.timeout.connect(func():
		# Убираем ингредиенты
		for ing in selected_recipe.ingredients:
			inventory.remove_from_total(ing.item, ing.amount)
		
		# Добавляем результат
		inventory.add_item(selected_recipe.result_item.duplicate(), selected_recipe.result_amount)
		
		_refresh()
		_update_preview()
	)

func _on_craft_max_pressed() -> void:
	if not selected_recipe or is_crafting:
		return
	
	var max_possible = _get_max_craftable_amount(selected_recipe)
	if max_possible <= 0:
		return
	
	_perform_craft(max_possible)

func _get_max_craftable_amount(recipe: CraftRecipe) -> int:
	var max_amount = 9999  # теоретический максимум
	
	for ing in recipe.ingredients:
		var available = inventory.get_total_item_count(ing.item)
		var needed_per_craft = ing.amount
		if needed_per_craft > 0:
			var can_make = available / needed_per_craft
			max_amount = mini(max_amount, can_make)
	
	return max_amount

func _perform_craft(amount: int) -> void:
	is_crafting = true
	craft_button.disabled = true
	craft_max_button.disabled = true
	#progress_bar.visible = false  # уже не нужен
	
	# Снимаем ингредиенты
	for ing in selected_recipe.ingredients:
		inventory.remove_from_total(ing.item, ing.amount * amount)
	
	# Добавляем результат
	inventory.add_item(selected_recipe.result_item.duplicate(), selected_recipe.result_amount * amount)
	
	is_crafting = false
	craft_button.disabled = false
	craft_max_button.disabled = false
	
	_refresh()
	_update_preview()


#func _input(event: InputEvent) -> void:
	#if Input.is_action_just_pressed("CallCrafting"):
		#visible = !visible
		#_update_recipe_list()


func _on_close_pressed() -> void:
	get_parent().get_parent().uncall_craft()
	Global.is_opened_menu = false
	Cursor.detection_mode( false)


func _on_sword_tag_pressed() -> void:
	category_filter.selected = 1
	_refresh()


func _on_pickaxa_tag_pressed() -> void:
	pass # Replace with function body.


func _on_items_tag_pressed() -> void:
	category_filter.selected = 3
	_refresh()
