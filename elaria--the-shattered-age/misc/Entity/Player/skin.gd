extends Node2D
class_name PlayerSkin

@export var player_skins: Array[Texture]
@export var player_sprites: Array[Sprite2D]
@onready var head_sprites : Sprite2D = $Body/Head
var skin_index: int = 0
var head_inex : int = 0 
func _ready():
	print("head index: " + str(Global.player_skin_head_index)+ "| Skin index : " + str(Global.player_skin_index))
	skin_index = Global.player_skin_index
	head_inex = Global.player_skin_head_index
	update_skin()

func update_skin():
	# Проверяем, есть ли скины для отображения
	if player_skins.size() == 0:
		return
	
	# Обеспечиваем корректный индекс (циклический перебор)
	skin_index = wrapi(skin_index, 0, player_skins.size())
	head_inex = wrapi(head_inex, 0, player_skins.size())
	
	# Применяем текстуру ко всем спрайтам
	for sprite in player_sprites:
		sprite.texture = player_skins[skin_index]
		head_sprites.texture = player_skins[head_inex]

func _on_next_pressed() -> void:
	skin_index += 1
	update_skin()

func _on_previus_pressed() -> void:
	skin_index -= 1
	update_skin()

func _on_next_head_pressed() -> void:
	head_inex += 1
	update_skin()

func _on_previus_head_pressed() -> void:
	head_inex -= 1
	update_skin()
