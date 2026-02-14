# TrashSlot.gd
extends TextureRect
class_name TrashSlot

# Очищаем предмет в курсоре — статическая функция для безопасного вызова извне
static func clear_held_item() -> void:
	InventorySlot.held_item = null
	InventorySlot.held_amount = 0
	
	# Безопасно очищаем превью, если оно существует
	if InventorySlot.held_preview and is_instance_valid(InventorySlot.held_preview):
		InventorySlot.held_preview.queue_free()
	InventorySlot.held_preview = null

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Можно дропнуть, если:
	# 1. Есть предмет в курсоре
	if InventorySlot.held_item != null:
		return true
	
	# 2. Перетаскиваем из слота инвентаря/хотбара
	if data is Dictionary and data.has("source_slot") and data.source_slot is InventorySlot:
		return data.source_slot.item != null
	
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var removed: bool = false
	
	# Случай 1: Удаляем предмет из курсора
	if InventorySlot.held_item != null:
		print("Удалено в мусорку из курсора: %s × %d" % [InventorySlot.held_item.item_name, InventorySlot.held_amount])
		
		clear_held_item()  # ← Используем статическую функцию
		removed = true
	
	# Случай 2: Удаляем предмет из слота (инвентарь или хотбар)
	elif data is Dictionary and data.has("source_slot") and data.source_slot is InventorySlot:
		var source_slot: InventorySlot = data.source_slot
		if not source_slot.item:
			return
		
		var container = source_slot.get_container()
		var slot_data = source_slot.get_slot_data()
		
		if slot_data and container:
			print("Удалено в мусорку: %s × %d" % [slot_data.item.item_name, slot_data.amount])
			
			# Очищаем слот
			slot_data.item = null
			slot_data.amount = 0
			source_slot._sync_from_data(slot_data)
			
			# Обновляем контейнер
			if container is Inventory:
				container.emit_signal("inventory_changed")
			elif container is Hotbar:
				container.emit_signal("hotbar_changed")
				container._recalculate_accessories()
			
			removed = true
	
	# Опционально: визуальный/звуковой эффект
	if removed:
		# $DeleteSound.play()
		# $DeleteParticles.emitting = true
		pass
func _on_mouse_entered() -> void:
	modulate = Color(1.5, 0.8, 0.8)  # Красноватый оттенок

func _on_mouse_exited() -> void:
	modulate = Color.WHITE
