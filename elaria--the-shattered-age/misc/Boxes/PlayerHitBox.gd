# PlayerHitBox.gd
extends HitBox
class_name player_HitBox

@export var equip_sprite: Sprite2D
@export var hand : equip_data

var is_weapon := false
var play_anim: String = "Attack"

@onready var hotbar: Hotbar = get_tree().get_first_node_in_group("Hotbar")

func _ready() -> void:
	connect("area_entered", hit)
	if hotbar:
		hotbar.hotbar_changed.connect(_on_hotbar_changed)
		# При старте сразу экипируем выбранный слот
		_update_from_hotbar()
	else:
		push_error("Hotbar not found! Add Hotbar node to group 'Hotbar'")

func _on_hotbar_changed() -> void:
	_update_from_hotbar()

func _update_from_hotbar() -> void:
	if not hotbar or hotbar.selected_index >= hotbar.slots.size():
		update_equip(null)
		return
	
	var slot_data = hotbar.slots[hotbar.selected_index]
	update_equip(slot_data.item)

func update_equip(new_equip : ItemData):
	print("updating equip sprite")
	equip = new_equip
	if equip is equip_data:
		play_anim = "Attack"
		equip_sprite.offset = Vector2(5.1, -3.66)
		equip_sprite.scale = Vector2(1,1)
		$CollisionShape2D.shape.radius = equip.hit_distance
		$CollisionShape2D.position.x = 6 + equip.hit_distance
		equip_sprite.rotation = 45
		equip_sprite.texture = equip.equiped_weapon_sprite
		is_weapon = true
		print("equiped weapon")

	elif equip is FoodData:
		print("equiped food")
		play_anim = "Eating"
		equip_sprite.offset = Vector2(0, 0)
		equip_sprite.scale = Vector2(0.5, 0.5)
		equip_sprite.rotation = 45
		equip_sprite.texture = equip.icon
		is_weapon = false
	elif equip is ItemData:
		print("equiped item")
		play_anim = "Attack"
		equip_sprite.offset = Vector2(0, 0)
		equip_sprite.scale = Vector2(0.5, 0.5)
		equip_sprite.rotation = 45
		equip_sprite.texture = equip.icon
		is_weapon = false
	else:
		equip = hand
		play_anim = "Attack"
		equip_sprite.texture = null
		is_weapon = false


#func hit(area: Area2D):
	#if not equip is equip_data:
		#return
	#
	#var ed = equip as equip_data
	#
	## Ranged оружие не использует melee collision
	#if ed.projectile:
		#return
	#
	#
	## Применяем урон
	#if area.is_in_group("Harvestable"):
		#area.Harvest(ed.Damage, ed.lvl, ed.is_weapon)
	#elif area.is_in_group("Ennemy"):
		#area.get_parent().take_damage(ed.Damage, self)
		#print("Melee damaged: " + str(ed.Damage))

func hit(area: Area2D):
	if not is_weapon:
		return
	
	var target_pos = area.global_position
	var mouse_pos = get_global_mouse_position()
	var dist_to_target = target_pos.distance_to(mouse_pos)
	
	# Проверка на промах
	if dist_to_target > equip.accuracy_radius:
		var miss_chance = min(1.0, (dist_to_target - equip.accuracy_radius) * equip.miss_chance_per_unit)
		if randf() < miss_chance:
			print("Промах!")
			return
	
	# Плавный расчёт модификатора урона
	var modified_damage = equip.Damage
	if dist_to_target <= equip.accuracy_radius:
		# Линейная интерполяция: от +2.5 (при dist=0) до +0 (при dist=accuracy_radius)
		var t = dist_to_target / equip.accuracy_radius
		modified_damage += lerp(2.5, 0.0, t)
	else:
		# Штраф от 0 до -2.5 в зависимости от превышения радиуса
		var excess_dist = dist_to_target - equip.accuracy_radius
		var penalty = min(2.5, excess_dist * 0.05)  # Например, -2.5 на 50 пикселях
		modified_damage -= penalty
	
	apply_damage(area, equip.Damage)

# Применение урона с учётом модифицированного значения
func apply_damage(area: Area2D, damage: float):
	if area.is_in_group("Harvestable"):
		area.Harvest(damage, equip.lvl, equip.is_weapon)
		
	elif area.is_in_group("Ennemy"):
		area.get_parent().take_damage(damage,self)
		print("weapon damaged: " + str(damage))


func consume_food(food: FoodData) -> void:
	if not hotbar: return
	
	var slot_data = hotbar.slots[hotbar.selected_index]
	if slot_data.amount <= 0:
		return
	
	# Уменьшаем количество
	slot_data.amount -= 1
	slot_data.slot_node.ammount = slot_data.amount
	slot_data.slot_node.update_ui()
	
	# Если кончилось — очищаем слот
	if slot_data.amount <= 0:
		slot_data.item = null
		slot_data.slot_node.item = null
		slot_data.slot_node.update_ui()
		update_equip(null)
	
	# Применяем эффекты еды
	_apply_food_effects(food)
	hotbar.emit_signal("hotbar_changed")

func _apply_food_effects(food: FoodData) -> void:
	if food.eat_sound:
		var player = AudioStreamPlayer.new()
		get_parent().add_child(player)
		player.stream = food.eat_sound
		player.play()
		player.finished.connect(player.queue_free)
	
	for effect in food.effects:
		# Здесь просто вызываем методы игрока
		var player = owner
		if player.effect_manager.has_method("apply_effect_instance"):
			player.apply_effect_instance(effect)
		# Или напрямую:
		if effect.effect_type == 0:  # Heal
			if player.has_method("heal"):
				player.heal(effect.value)

func eat_food():
	if not equip:
		return
		
	if equip is FoodData:
		consume_food(equip as FoodData)


func _on_animation_player_animation_started(anim_name: StringName) -> void:
	if anim_name == "Eating":
		consume_food(equip as FoodData)
