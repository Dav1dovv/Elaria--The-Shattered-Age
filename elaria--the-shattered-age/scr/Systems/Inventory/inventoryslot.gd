# inventoryslot.gd
extends TextureButton
class_name InventorySlot

var inventory: Inventory = null
var hotbar: Hotbar = null
var hotbar_index: int = -1

@export var active_slot: AtlasTexture
@export var unactive_slot: AtlasTexture

var item: ItemData = null
var ammount: int = 0

# Глобальный "предмет в курсоре" — общий для всех слотов
static var held_item: ItemData = null
static var held_amount: int = 0
static var held_preview: Control = null

func _ready() -> void:
	if get_parent() is Hotbar:
		hotbar = get_parent()
		hotbar_index = get_index()

func get_container() -> Node:
	if inventory: return inventory
	if hotbar: return hotbar
	var p = get_parent()
	while p:
		if p is Inventory or p is Hotbar:
			return p
		p = p.get_parent()
	return null

func get_slot_data() -> InventorySlotData:
	var container = get_container()
	if not container: return null
	if container is Inventory:
		return container.get_slot_data_by_node(self)
	elif container is Hotbar:
		return container.get_slot_data_by_node(self)
	return null

func update_ui() -> void:
	$Icon.texture = item.icon if item else null
	$Count.text = str(ammount) if ammount > 1 else ""

	if item is AccessoryData:
		$Border.visible = true
		$Border.modulate = (item as AccessoryData).ui_border_color
	else:
		$Border.visible = false

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("source_slot") and data.source_slot != self

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_slot: InventorySlot = data.source_slot
	var dragged_item: ItemData = data.item
	var dragged_amount: int = data.amount

	var source_container = source_slot.get_container() if source_slot else null
	var target_container = get_container()
	var target_data = get_slot_data()

	if not target_data or not target_container:
		return

	var source_data = source_slot.get_slot_data() if source_slot else null

	# ИСПРАВЛЕНО: используем статическую функцию
	var same_item = dragged_item and target_data.item and InventorySlot.is_same_item(dragged_item, target_data.item)

	var transferred: int = 0

	# 1. Пустой слот
	if not target_data.item:
		target_data.item = dragged_item
		target_data.amount = dragged_amount
		transferred = dragged_amount

	# 2. Стакаем одинаковые
	elif same_item and dragged_item.stackable:
		var space = dragged_item.max_count - target_data.amount
		if space > 0:
			transferred = min(dragged_amount, space)
			target_data.amount += transferred

	# 3. Меняем местами разные предметы
	else:
		var temp_item = target_data.item
		var temp_amount = target_data.amount

		target_data.item = dragged_item
		target_data.amount = dragged_amount
		transferred = dragged_amount

		if source_data:
			source_data.item = temp_item
			source_data.amount = temp_amount

	# Уменьшаем источник
	if source_data:
		source_data.amount -= transferred
		if source_data.amount <= 0:
			source_data.item = null
			source_data.amount = 0
		source_slot._sync_from_data(source_data)

	# Если дроп из курсора — очищаем его
	if held_item:
		held_item = null
		held_amount = 0
		_clear_held_preview()

	_sync_from_data(target_data)

	_emit_container_changed(source_container)
	_emit_container_changed(target_container)

func _emit_container_changed(container: Node) -> void:
	if not container: return
	if container is Inventory:
		container.emit_signal("inventory_changed")
	elif container is Hotbar:
		container.emit_signal("hotbar_changed")
		container._recalculate_accessories()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not item or ammount <= 0:
		return null

	var drag_amount = ammount
	if Input.is_key_pressed(KEY_CTRL):
		drag_amount = 1
	elif Input.is_key_pressed(KEY_SHIFT) and ammount > 1:
		drag_amount = ceili(ammount / 2.0)

	# Берём в курсор
	_take_to_cursor(drag_amount)

	# Уменьшаем в слоте
	var data = get_slot_data()
	data.amount -= drag_amount
	if data.amount <= 0:
		data.item = null
		data.amount = 0
	_sync_from_data(data)

	_emit_container_changed(get_container())

	return {
		"source_slot": self,
		"item": held_item,
		"amount": held_amount
	}

# Основная функция: взять предмет в курсор
func _take_to_cursor(amount: int) -> void:
	held_item = item
	held_amount = amount
	_create_or_update_held_preview()

# Создаёт или обновляет превью на курсоре
func _create_or_update_held_preview() -> void:
	_clear_held_preview()  # На всякий случай чистим старое

	if not held_item:
		return

	held_preview = Control.new()
	held_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Не блокирует клики

	var icon = TextureRect.new()
	icon.texture = held_item.icon
	icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	icon.size = Vector2(19, 19)
	icon.position = Vector2(-8, -8)
	held_preview.add_child(icon)

	if held_amount > 1:
		var label = Label.new()
		label.text = str(held_amount)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.size = Vector2(16, 18)
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		icon.add_child(label)

	# Добавляем в корень сцены, чтобы было поверх всего
	get_tree().get_first_node_in_group("Inventory").add_child(held_preview)
	_update_held_preview_position()

func _update_held_preview_position() -> void:
	if held_preview and is_instance_valid(held_preview):
		held_preview.global_position = get_global_mouse_position() + Vector2(10, -10)

func _clear_held_preview() -> void:
	if held_preview and is_instance_valid(held_preview):
		held_preview.queue_free()
	held_preview = null

# Обновляем позицию каждый кадр — идеально точно следует за мышью
func _process(_delta: float) -> void:
	_update_held_preview_position()

# Обработка кликов
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Правый клик — разделить пополам и взять половину в курсор
		if event.button_index == MOUSE_BUTTON_RIGHT and item and ammount > 1:
			accept_event()

			var half = ceili(ammount / 2.0)
			_take_to_cursor(half)

			var data = get_slot_data()
			data.amount -= half
			if data.amount <= 0:
				data.item = null
				data.amount = 0
			_sync_from_data(data)

			_emit_container_changed(get_container())

		# Левый клик по пустому слоту с предметом в курсоре — положить
		elif event.button_index == MOUSE_BUTTON_LEFT and held_item and (!item or ammount == 0):
			accept_event()

			var data = get_slot_data()
			data.item = held_item
			data.amount = held_amount
			_sync_from_data(data)

			_emit_container_changed(get_container())

			# Очищаем курсор
			held_item = null
			held_amount = 0
			_clear_held_preview()

		# Shift + ЛК — быстрый перенос
		elif event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SHIFT):
			accept_event()
			_quick_transfer()

func _quick_transfer() -> void:
	var container = get_container()
	if not container or not item: return

	var target = null
	if container is Inventory and Global.hotbar:
		target = Global.hotbar
	elif container is Hotbar and Global.inventory:
		target = Global.inventory

	if not target: return

	if target.add_item(item, ammount):
		var data = get_slot_data()
		data.item = null
		data.amount = 0
		_sync_from_data(data)
		_emit_container_changed(container)

func _sync_from_data(data: InventorySlotData) -> void:
	if not data:
		item = null
		ammount = 0
	else:
		item = data.item
		ammount = data.amount
	update_ui()

func _on_mouse_entered() -> void:
	if item:
		var desc = item.description
		if item is equip_data:
			desc = "DMG: %s\nRange: %s\nSpeed: %s" % [item.Damage, item.hit_distance, item.Atk_speed]
		elif item is FoodData:
			desc += "\nEffects:"
			for effect in item.effects:
				desc += "\n- %s: +%s (%s sec)" % [effect.effect_type, effect.value, effect.duration]
		$Tooltip.show_tooltip(item.item_name, desc)

func _on_mouse_exited() -> void:
	$Tooltip.hide_tooltip()

func activate_slot() -> void:
	texture_normal = active_slot

func disable_slot() -> void:
	texture_normal = unactive_slot


# В начале файла, после class_name InventorySlot
static func is_same_item(a: ItemData, b: ItemData) -> bool:
	if a == null or b == null:
		return false
	# Сначала по пути — самый точный
	if a.resource_path != "" and b.resource_path != "" and a.resource_path == b.resource_path:
		return true
	# Если путь пустой (дубликат) — по имени и типу
	if a.item_name == b.item_name and a.get_class() == b.get_class():
		return true
	return false
