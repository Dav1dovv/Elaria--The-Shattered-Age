extends Node

var player_name: String = "Deffault"
var player_skin_index: int = 0
var player_skin_head_index: int = 0
var game_difficult : int = 0
var current_save_slot: String = ""
var current_location : String = "Land"

var game_progress : int = 0
var is_opened_menu : bool = false

var hotbar
var inventory : Inventory

var explored_progress : float = 0

const MOUSE_Arrow = preload("res://Assets/Textures/UI/Cursors/Cursor1.png")
const HINT = preload("uid://wyeldfaexejh")


@onready var developer_console: CanvasLayer = %DeveloperConsole
@onready var scene_manager: SceneManager = $SceneManager
@onready var blaze_music_manager: BlazeMusicManager = %MusicManager
@onready var setting_manager: SettingManager = $SettingManager


func _init() -> void:
	#Input.set_custom_mouse_cursor(MOUSE_Interact,Input.CURSOR_CAN_DROP,Vector2(11,13))
	Input.set_custom_mouse_cursor(MOUSE_Arrow,Input.CURSOR_ARROW,Vector2(0,0))
	
func _ready() -> void:
	# Register singleton
	if not Engine.has_singleton("Global"):
		Engine.register_singleton("Global", self)
	
	# Create Saves directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if dir:
		dir.make_dir("Saves")
		
	

# Set character name and create folder
func set_character_name(new_name: String):
	if new_name.strip_edges().is_empty():
		print("Error: Character name cannot be empty")
		return
	player_name = new_name.strip_edges()
	print("Global character name set to: %s" % player_name)
	
	# Create character folder
	var save_dir = "user://Saves/%s" % player_name.replace(" ", "_")
	var dir = DirAccess.open("user://Saves")
	if dir:
		dir.make_dir(save_dir)

func pickup_item(item_data: ItemData, amount: int = 1) -> void:
	
	if not hotbar or not inventory:
		print("Ошибка: Hotbar или Inventory не найдены!")
		return
	
	# 1. Сначала пытаемся положить в ХОТБАР
	var added_to_hotbar = _try_add_to_container(hotbar, item_data, amount)
	
	if added_to_hotbar:
		print("Предмет добавлен в хотбар: ", item_data.item_name)
		return
	
	# 2. Если хотбар полон — кладём в основной инвентарь
	var added_to_inventory = _try_add_to_container(inventory, item_data, amount)
	
	if added_to_inventory:
		print("Предмет добавлен в инвентарь: ", item_data.item_name)
	else:
		print("Инвентарь и хотбар полные! Предмет потерян: ", item_data.item_name)
		# Можно показать уведомление игроку

func _try_add_to_container(container, item_data: ItemData, amount: int) -> bool:
	if not container or not container.has_method("add_item"):
		return false
	
	# Попробуем добавить — возвращает true, если хоть что-то добавилось
	return container.add_item(item_data, amount)

func add_initial_items():
	pickup_item(preload("uid://ch2r3sdjgisqa").duplicate(), 1)
	pickup_item(preload("uid://prg8cq5chkl2").duplicate(), 1)
	pickup_item(preload("uid://xyck3q0gr12o").duplicate(),1)
	pass

# Get full path to save file
func get_save_path() -> String:
	if player_name.is_empty():
		print("Error: Character name is empty")
		return ""
	return "user://Saves/%s/save.json" % player_name.replace(" ", "_")


func hint(object : Node2D,message : String):
		print("hint working")
		var hint_instant = HINT.instantiate()
		hint_instant.text = message
		hint_instant.position = object.global_position
		hint_instant.position.y -= 10
		object.call_deferred("add_child",hint_instant)

func save():
	get_tree().call_group("Save","save_game")
