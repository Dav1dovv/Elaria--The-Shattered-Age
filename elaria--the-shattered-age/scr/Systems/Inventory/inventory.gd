# inventory.gd
extends Control
class_name Inventory

signal inventory_changed

@onready var grid_container: GridContainer = $HBoxContainer/Inventory/VBoxContainer/GridContainer
@onready var hotbar: Hotbar = $HotBar
var items: Array[InventorySlotData] = []
var items_storage :Array[ItemData]

func _init() -> void:
	_load_all_items()

func _ready() -> void:
	_initialize_slots()
	Global.inventory = self
	Global.developer_console.register_command("all_items_list", _cmd_list, "List all items")
	Global.developer_console.register_command("add_item",_cmd_add_item, "Usage: add_item [itm_indx] [count]")
	#$InventorySaver.load_game()

func _load_all_items() -> void:
	var dir = DirAccess.open("res://scr/Resources/Items/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var itm = load("res://scr/Resources/Items/" + file_name)
				if itm is ItemData:
					items_storage.append(itm)
			file_name = dir.get_next()

func _get_items_list() -> String:
	var list = "all items list:\n"
	for i in range(items_storage.size()):
		var config = items_storage[i]
		var itm = "EMPTY" if not config else config.item_name
		list += "%d: %s\n" % [i, itm]
	return list

func _initialize_slots() -> void:
	items.clear()
	for child in grid_container.get_children():
		if child is InventorySlot:
			var data = InventorySlotData.new()
			data.slot_node = child
			items.append(data)
			child.inventory = self

func add_item(item_data: ItemData, amount: int = 1) -> bool:
	if not item_data or amount <= 0:
		return false

	var remaining = amount

	# 1. Стакаем в существующие слоты с таким же предметом
	for data in items:
		if remaining <= 0: break
		if data.item and _is_same_item(data.item, item_data) and item_data.stackable:
			var space = item_data.max_count - data.amount
			if space > 0:
				var add = min(remaining, space)
				data.amount += add
				data.slot_node.item   = data.item
				data.slot_node.ammount = data.amount
				data.slot_node.update_ui()
				remaining -= add

	# 2. Раскладываем остаток по пустым слотам
	for data in items:
		if remaining <= 0: break
		if data.item == null:
			# Дублируем чтобы каждый слот имел свою копию ресурса
			data.item = item_data.duplicate()
			var add   = min(remaining, item_data.max_count)
			data.amount = add
			data.slot_node.item    = data.item
			data.slot_node.ammount = data.amount
			data.slot_node.update_ui()
			remaining -= add

	if remaining < amount:
		emit_signal("inventory_changed")
		return true

	print("Inventory full!")
	return false

func _is_same_item(a: ItemData, b: ItemData) -> bool:
	if a == null or b == null:
		return false
	if a.resource_path != "" and a.resource_path == b.resource_path:
		return true
	if a.item_name == b.item_name and a.get_class() == b.get_class():
		return true
	return false

func get_total_item_count(search_item: ItemData) -> int:
	if not search_item:
		return 0
	var total: int = 0
	if hotbar and hotbar.slots:
		for slot_data in hotbar.slots:
			if _is_same_item(slot_data.item, search_item):
				total += slot_data.amount
	for slot_data in items:
		if _is_same_item(slot_data.item, search_item):
			total += slot_data.amount
	return total

func has_total_item(search_item: ItemData, required_amount: int) -> bool:
	return get_total_item_count(search_item) >= required_amount

func remove_from_total(search_item: ItemData, amount: int) -> bool:
	if amount <= 0 or not search_item:
		return true

	var remaining: int = amount
	var changed: bool = false

	# Хотбар
	if hotbar and hotbar.slots:
		for slot_data in hotbar.slots:
			if remaining <= 0: break
			if _is_same_item(slot_data.item, search_item):
				var remove_amt = min(remaining, slot_data.amount)
				slot_data.amount -= remove_amt
				remaining -= remove_amt
				changed = true
				if slot_data.amount <= 0:
					slot_data.item = null
					slot_data.slot_node.item = null
				slot_data.slot_node.ammount = slot_data.amount
				slot_data.slot_node.update_ui()

	# Инвентарь
	for slot_data in items:
		if remaining <= 0: break
		if _is_same_item(slot_data.item, search_item):
			var remove_amt = min(remaining, slot_data.amount)
			slot_data.amount -= remove_amt
			remaining -= remove_amt
			changed = true
			if slot_data.amount <= 0:
				slot_data.item = null
				slot_data.slot_node.item = null
			slot_data.slot_node.ammount = slot_data.amount
			slot_data.slot_node.update_ui()

	if changed:
		emit_signal("inventory_changed")
		if hotbar:
			hotbar.emit_signal("hotbar_changed")
			hotbar._recalculate_accessories()

	return remaining <= 0

func get_slot_data_by_node(slot_node: InventorySlot) -> InventorySlotData:
	for data in items:
		if data.slot_node == slot_node:
			return data
	return null

func get_save_path() -> String:
	return "user://Saves/%s/inventory.save" % Global.player_name

var is_opened : bool = false

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("CallInventory"):
		toggle_inv()

func toggle_inv():
	call_inventory()

func can_add_item(item_data: ItemData, amount: int = 1) -> bool:
	if amount <= 0:
		return true

	var remaining: int = amount
	var all_slots: Array[InventorySlotData] = items.duplicate()

	if hotbar and hotbar.slots:
		all_slots.append_array(hotbar.slots)

	for slot_data in all_slots:
		if slot_data.item and _is_same_item(slot_data.item, item_data) and item_data.stackable:
			var space: int = item_data.max_count - slot_data.amount
			if space > 0:
				remaining -= min(remaining, space)
				if remaining <= 0:
					return true

	if remaining > 0:
		for slot_data in all_slots:
			if slot_data.item == null:
				return true

	return false

func _cmd_list(_args: Array) -> String:
	return _get_items_list()

func _cmd_add_item(args: Array) -> String:
	if args.size() != 2:
		return "Usage: add_item [itm_index] [count]"
	var index = args[0] as int
	var count = args[1] as int
	if index < 0 or index >= items_storage.size():
		return "Error: invalid item index (use /all_items_list to see indices)"
	if count <= 0:
		return "Error: count must be > 0"
	var item_data = items_storage[index]
	Global.pickup_item(item_data, count)
	return "Added %d × %s" % [count, item_data.item_name]

func call_inventory():
	if Global.is_opened_menu && !is_opened:
		return

	is_opened = !is_opened
	Global.is_opened_menu = is_opened
	$HBoxContainer.visible = is_opened
	$HBoxContainer/Inventory.visible = true

	Cursor.detection_mode(is_opened)

func uncall_craft():
	is_opened = !is_opened
	Global.is_opened_menu = is_opened
	$HBoxContainer.visible = is_opened
	$HBoxContainer/Inventory.visible = false
	$HBoxContainer/WorkBench.visible = false
	$HBoxContainer/sciencist.visible = false
func call_craft():
	if Global.is_opened_menu && !is_opened:
		return

	is_opened = !is_opened
	Global.is_opened_menu = is_opened
	$HBoxContainer.visible = is_opened
	$HBoxContainer/Inventory.visible = true
	$HBoxContainer/WorkBench.visible = true
	$HBoxContainer/WorkBench._refresh()
	$HBoxContainer/WorkBench._update_preview()

func call_sciensist():
	$HBoxContainer/Inventory.visible = true
	$HBoxContainer/sciencist.visible = true
	$HBoxContainer/sciencist._refresh()
	$HBoxContainer/sciencist._update_preview()
