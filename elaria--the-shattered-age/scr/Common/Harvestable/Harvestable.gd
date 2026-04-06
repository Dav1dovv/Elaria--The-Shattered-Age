extends Area2D
class_name Harvestable

signal collected


@onready var Dropper_component = $droper
@export_range(2,999,1) var durability : float = 6
@export_range(0,10) var harvest_tool_lvl : int = 1
@export var VFX_component : VFX

var player
var tween: Tween

@export_group("Transparency Settings")
@export_range(0.0, 200.0, 10.0) var max_distance : float = 20  # Макс расстояние для fade
@export_range(0.0, 1.0, 0.01) var fade_alpha : float = 0.50      # Прозрачность сзади
@export_range(0.1, 1.0, 0.05) var fade_duration : float = 0.2   # Скорость анимации

func _init() -> void:
	set_collision_layer_value(2,true)
	set_collision_layer_value(5,true)
	set_collision_mask_value(1,false)
	set_collision_mask_value(4,true)
	#set_collision_layer_value(8,true)
	set_collision_mask_value(9,true)

func _ready() -> void:
	add_to_group("Harvestable")
	if not is_inside_tree():
		await tree_entered
	
	Dropper_component = $droper
	
	player = get_tree().get_first_node_in_group("Player")
	connect("area_entered",_on_area_entered)
	connect("area_exited",_on_area_exited)
	# Начальная проверка
	#update_transparency()

func _physics_process(delta: float) -> void:
	if player == null:
		modulate_tween(Color.WHITE)
		return
	
	update_transparency()

func update_transparency() -> void:
	if player == null:
		modulate_tween(Color.WHITE)
		return
	
	var distance = global_position.distance_to(player.global_position)
	var player_behind = player.global_position.y < global_position.y  # Игрок ниже = сзади
	
	if player_behind and distance < max_distance:
		modulate_tween(Color(1,1,1, fade_alpha))
	else:
		modulate_tween(Color.WHITE)

func modulate_tween(target_color: Color) -> void:
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(self, "modulate", target_color, fade_duration)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func Harvest(hit_strenght : float, tool_lvl:int,is_weapon:bool):
	if is_weapon:
		return
	if tool_lvl >= harvest_tool_lvl:
		if VFX_component != null: 
			VFX_component._hit_vfx($Sprite2D)
			await VFX_component.vfx_finished
		
		durability -= hit_strenght
	else:
		
		Global.hint(self,"you need lvl " + str(harvest_tool_lvl) + " pickaxe")
		
	
	if durability <= 0:
		if VFX_component: await VFX_component.vfx_finished
		if $Destroy: $Destroy.play()
		if Dropper_component != null: 
			# Исправил странную строку (было выражение без присваивания)
			Dropper_component.max_drop += scale.x
			Dropper_component._drop_items()
		emit_signal("collected")
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	print("mouse_enetered")
	
	if area.is_in_group("cursor"):
		area.change_curosr("gather")


func _on_area_exited(area: Area2D) -> void:
	print("mouse_exited")
	if area.is_in_group("cursor"):
		area.change_curosr("simple")
