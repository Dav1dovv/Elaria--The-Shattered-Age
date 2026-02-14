@tool
extends Area2D
class_name HurtBox

@export var Path_to_stat : Node2D

func _init() -> void:
	set_collision_layer_value(1,false)
	set_collision_layer_value(5,true)
	set_collision_mask_value(1,false)
	set_collision_mask_value(4,true)

func _ready() -> void:
	get_parent().connect("health_changed",damaged)

func damaged(area):
	get_child(0).disabled = true
	await get_tree().create_timer(1).timeout
	get_child(0).disabled = false
