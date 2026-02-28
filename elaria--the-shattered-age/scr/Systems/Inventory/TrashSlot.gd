# TrashSlot.gd
extends TextureRect
class_name TrashSlot

# Удаляем предмет из курсора (held_item)
static func clear_held_item() -> void:
	InventorySlot.held_item   = null
	InventorySlot.held_amount = 0
	if InventorySlot.held_preview and is_instance_valid(InventorySlot.held_preview):
		InventorySlot.held_preview.queue_free()
	InventorySlot.held_preview = null

func _gui_input(event: InputEvent) -> void:
	# Клик ЛКМ по корзине — удалить предмет из курсора
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if InventorySlot.held_item != null:
			accept_event()
			print("Удалено в мусорку: %s × %d" % [InventorySlot.held_item.item_name, InventorySlot.held_amount])
			clear_held_item()

func _on_mouse_entered() -> void:
	modulate = Color(1.5, 0.8, 0.8)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE
