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
		# Подключаем сигналы прочности
		if not equip.weapon_broken.is_connected(_on_weapon_broken):
			equip.weapon_broken.connect(_on_weapon_broken)
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

func _on_weapon_broken() -> void:
	print("Оружие сломано!")
	# Визуальная обратная связь — мигание красным
	var tween = create_tween()
	tween.tween_property(equip_sprite, "modulate", Color(1, 0.2, 0.2), 0.1)
	tween.tween_property(equip_sprite, "modulate", Color(1, 1, 1), 0.1)
	tween.tween_property(equip_sprite, "modulate", Color(1, 0.2, 0.2), 0.1)
	tween.tween_property(equip_sprite, "modulate", Color(0.4, 0.4, 0.4), 0.2)

func hit(area: Area2D):
	if not is_weapon:
		return
	
	# Проверяем прочность перед ударом
	if equip is equip_data and equip.is_broken():
		print("Оружие сломано — удар не наносится!")
		return

	apply_damage(area, equip.Damage)
	
	# Уменьшаем прочность после успешного удара
	if equip is equip_data:
		equip.reduce_durability(1)
		# Обновляем UI слота хотбара
		_refresh_hotbar_slot_ui()

func apply_damage(area: Area2D, damage: float):
	if area.is_in_group("Harvestable"):
		area.Harvest(damage, equip.lvl, equip.is_weapon)
		
	elif area.is_in_group("Ennemy"):
		area.get_parent().take_damage(damage, self)
		print("weapon damaged: " + str(damage))

func _refresh_hotbar_slot_ui() -> void:
	if not hotbar: return
	var slot_data = hotbar.slots[hotbar.selected_index]
	if slot_data.slot_node:
		slot_data.slot_node.update_ui()

func consume_food(food: FoodData) -> void:
	if not hotbar: return
	
	var slot_data = hotbar.slots[hotbar.selected_index]
	if slot_data.amount <= 0:
		return
	
	slot_data.amount -= 1
	slot_data.slot_node.ammount = slot_data.amount
	slot_data.slot_node.update_ui()
	
	if slot_data.amount <= 0:
		slot_data.item = null
		slot_data.slot_node.item = null
		slot_data.slot_node.update_ui()
		update_equip(null)
	
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
		var player = owner
		if player.effect_manager.has_method("apply_effect_instance"):
			player.apply_effect_instance(effect)
		if effect.effect_type == 0:
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
