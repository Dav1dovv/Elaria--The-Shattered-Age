extends Control

@onready var name_: Label = $Panel/VBoxContainer/Name
@onready var label = $Panel/VBoxContainer/Description

var screen_size : Vector2

func _ready():
	hide_tooltip()

func show_tooltip(item_name: String, text: String):
	visible = true
	name_.text = item_name  # Здесь передавайте item.display_name
	label.text = text
# ❌ Скрываем описание
func hide_tooltip():
	visible = false
	pass
