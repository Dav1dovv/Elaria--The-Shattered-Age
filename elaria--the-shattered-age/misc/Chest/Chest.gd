extends Node2D

#@export var chest_lvl_sprite : Array[Texture2D]
@export var drop_pools : Array[LootPool]  # Массив пулов лута для каждого уровня
@export var need_tool : Array[ItemData]
@export var sprites : Array[Texture]

@onready var interaction : interaction_area = $interaction_area
#@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var player = get_tree().get_first_node_in_group("Player")
var is_opened = false
var chest_lvl : int = 1
var need_key : bool = false
var need : ItemData

func _ready():
	randomize()
	chest_lvl = randi() % sprites.size()
	
	if chest_lvl > 0: 
		need_key = randi()
		$Sprite2D.texture = sprites[chest_lvl]
	if need_key:
		need = need_tool.pick_random()
		interaction.icon_help = need.icon
		interaction.show_message = ""
	interaction.interact = Callable(self, "open")
#	interaction.toDo = "X " + str(need_exp)

func open():
	if need_key:
		if !is_opened and need != null and Global.inventory.has_total_item(need,1):
			$AnimationPlayer.play("Open")
			Global.inventory.remove_from_total(need,1)
			is_opened = true
			$interaction_area.queue_free()
		elif !is_opened and need == null:
			$AnimationPlayer.play("Open")
			is_opened = true
			$interaction_area.queue_free()
		else:
			$SFX.play()
			if need != null:
				Global.hint(self,"you need " + need.item_name)
			else:
				Global.hint(self,"this is bug")
	else:
			$AnimationPlayer.play("Open")
			is_opened = true
func Loot():
	if is_opened:
		#particles.restart()
		#particles.emitting = true
		
		# Получаем пул лута для текущего уровня сундука
		var current_pool = drop_pools[chest_lvl]
		
		# Определяем количество предметов для дропа
		var items_to_drop = randi_range(current_pool.min_items, current_pool.max_items)
		
		for i in range(items_to_drop):
			# Используем метод get_random_item из LootPool
			var dropped_item = current_pool.get_random_item()
			if dropped_item:
				var item_copy = dropped_item.duplicate(true)
				item_copy.icon = dropped_item.icon.duplicate() if dropped_item.icon else null
				
				# Меняем силу урона у копии
				var s = item_copy.damage_strength * randf_range(0.5, chest_lvl+1) 
				item_copy.damage_strength = floorf(s)
				print("weapon strength " + str(floorf(s)))
		
		$Sprite2D.frame += 1

func _on_timer_timeout() -> void:
	queue_free()
