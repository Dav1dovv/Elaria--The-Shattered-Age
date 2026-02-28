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

# ── Глобальный курсор (один на всю игру) ─────────────────────────────────────
static var held_item:    ItemData = null
static var held_amount:  int      = 0
static var held_preview: Control  = null

# Флаг: «в этом кадре был начат drag» — чтобы _gui_input не реагировал
# на тот же клик, которым мы подняли предмет.
static var _drag_started_this_frame: bool = false

func _ready() -> void:
	if get_parent() is Hotbar:
		hotbar       = get_parent()
		hotbar_index = get_index()
	_ensure_durability_bar()

# ── Durability bar ────────────────────────────────────────────────────────────
func _ensure_durability_bar() -> void:
	var bar := get_node_or_null("DurabilityBar") as TextureProgressBar
	if bar:
		bar.visible = false

func _update_durability_bar() -> void:
	var bar := get_node_or_null("DurabilityBar") as TextureProgressBar
	if not bar:
		return
	if item is equip_data:
		var current: float = float(item.get_durability())
		var maximum: float = float(item.max_durability)
		bar.min_value = 0.0
		bar.max_value = maximum
		bar.visible   = true
		bar.set_deferred("value", current)
		var ratio: float = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
		if   ratio > 0.6: bar.tint_progress = Color(0.2, 0.85, 0.2)
		elif ratio > 0.3: bar.tint_progress = Color(0.95, 0.75, 0.1)
		else:             bar.tint_progress = Color(0.9, 0.15, 0.15)
		$Icon.modulate = Color(0.45, 0.45, 0.45) if item.is_broken() else Color.WHITE
	else:
		bar.visible    = false
		$Icon.modulate = Color.WHITE

# ── Утилиты ───────────────────────────────────────────────────────────────────
func get_container() -> Node:
	if inventory: return inventory
	if hotbar:    return hotbar
	var p = get_parent()
	while p:
		if p is Inventory or p is Hotbar: return p
		p = p.get_parent()
	return null

func get_slot_data() -> InventorySlotData:
	var c = get_container()
	if not c: return null
	if c is Inventory: return c.get_slot_data_by_node(self)
	if c is Hotbar:    return c.get_slot_data_by_node(self)
	return null

func update_ui() -> void:
	$Icon.texture = item.icon if item else null
	$Count.text   = str(ammount) if ammount > 1 else ""
	if item is AccessoryData:
		$Border.visible  = true
		$Border.modulate = (item as AccessoryData).ui_border_color
	else:
		$Border.visible = false
	_update_durability_bar()

func _sync_from_data(data: InventorySlotData) -> void:
	if not data: item = null; ammount = 0
	else:        item = data.item; ammount = data.amount
	update_ui()

func _emit_changed(container: Node) -> void:
	if not container: return
	if container is Inventory:
		container.emit_signal("inventory_changed")
	elif container is Hotbar:
		container.emit_signal("hotbar_changed")
		container._recalculate_accessories()

# ── DRAG-AND-DROP GODOT — ПОЛНОСТЬЮ ОТКЛЮЧЁН ─────────────────────────────────
# Возвращаем null — Godot не будет инициировать свой drag.
# Вся логика перетаскивания идёт через held_item + _gui_input.
func _get_drag_data(_pos: Vector2) -> Variant:
	return null

func _can_drop_data(_pos: Vector2, _data: Variant) -> bool:
	return false

# ── Основная логика ввода ─────────────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	var btn = event.button_index

	# ═══════════════════════════════════════════════════════════════════
	# ЛКМ
	# ═══════════════════════════════════════════════════════════════════
	if btn == MOUSE_BUTTON_LEFT:

		# Shift+ЛКМ (курсор пуст) — быстрый перенос
		if Input.is_key_pressed(KEY_SHIFT) and held_item == null:
			accept_event()
			_quick_transfer()
			return

		# Курсор пуст — ПОДНЯТЬ предмет из слота
		if held_item == null:
			if not item or ammount <= 0:
				return
			accept_event()

			var pick_amount = ammount
			if Input.is_key_pressed(KEY_CTRL):
				pick_amount = 1
			# Shift занят только для transfer, Ctrl — для 1 шт

			var data = get_slot_data()
			if not data: return

			held_item   = data.item   # берём ссылку
			held_amount = pick_amount

			data.amount -= pick_amount
			if data.amount <= 0:
				data.item   = null
				data.amount = 0
			_sync_from_data(data)
			_emit_changed(get_container())
			_refresh_preview()

		# Курсор занят — ПОЛОЖИТЬ предмет в слот
		else:
			accept_event()
			_place_held_into_slot()

	# ═══════════════════════════════════════════════════════════════════
	# ПКМ
	# ═══════════════════════════════════════════════════════════════════
	elif btn == MOUSE_BUTTON_RIGHT:

		# Курсор пуст + слот не пуст — взять половину
		if held_item == null and item and ammount > 0:
			accept_event()
			var half = ceili(ammount / 2.0)
			var data = get_slot_data()
			if not data: return

			held_item   = data.item
			held_amount = half

			data.amount -= half
			if data.amount <= 0:
				data.item   = null
				data.amount = 0
			_sync_from_data(data)
			_emit_changed(get_container())
			_refresh_preview()

		# Курсор занят — положить 1 штуку в слот
		elif held_item != null:
			accept_event()
			var data = get_slot_data()
			if not data: return

			# Слот пустой или совпадающий предмет
			if data.item == null or is_same_item(data.item, held_item):
				var max_c = held_item.max_count
				var space = max_c - data.amount
				if space > 0:
					if data.item == null:
						data.item = held_item
					data.amount  += 1
					held_amount  -= 1
					if held_amount <= 0:
						held_item   = null
						held_amount = 0
						_clear_preview()
					else:
						_refresh_preview()
					_sync_from_data(data)
					_emit_changed(get_container())

# ── Положить held в текущий слот ─────────────────────────────────────────────
func _place_held_into_slot() -> void:
	var data = get_slot_data()
	if not data: return

	var container = get_container()

	# Слот пустой — просто кладём
	if data.item == null:
		data.item   = held_item
		data.amount = held_amount
		held_item   = null
		held_amount = 0
		_clear_preview()
		_sync_from_data(data)
		_emit_changed(container)
		return

	# Тот же предмет — стакаем
	if is_same_item(data.item, held_item) and held_item.stackable:
		var space = held_item.max_count - data.amount
		if space > 0:
			var add      = min(held_amount, space)
			data.amount += add
			held_amount -= add
			if held_amount <= 0:
				held_item   = null
				held_amount = 0
				_clear_preview()
			else:
				_refresh_preview()
			_sync_from_data(data)
			_emit_changed(container)
		# Нет места — ничего не делаем (предмет остаётся в курсоре)
		return

	# Разные предметы — свап
	var tmp_item   = data.item
	var tmp_amount = data.amount
	data.item    = held_item
	data.amount  = held_amount
	held_item    = tmp_item
	held_amount  = tmp_amount
	_refresh_preview()
	_sync_from_data(data)
	_emit_changed(container)

# ── Быстрый перенос Shift+ЛКМ ────────────────────────────────────────────────
func _quick_transfer() -> void:
	var container = get_container()
	if not container or not item: return

	var target: Node = null
	if   container is Inventory and Global.hotbar:    target = Global.hotbar
	elif container is Hotbar    and Global.inventory: target = Global.inventory
	if not target: return

	var data = get_slot_data()
	if not data: return

	var can_fit = _calc_can_fit(target, item, data.amount)
	if can_fit <= 0: return

	var xfer_item   = item
	var xfer_amount = can_fit

	if target.add_item(xfer_item, xfer_amount):
		data.amount -= xfer_amount
		if data.amount <= 0:
			data.item   = null
			data.amount = 0
		_sync_from_data(data)
		_emit_changed(container)

func _calc_can_fit(target: Node, itm: ItemData, amount: int) -> int:
	var remaining = amount
	var slots_list: Array = []
	if   target is Inventory: slots_list = target.items
	elif target is Hotbar:    slots_list = target.slots

	for sd in slots_list:
		if remaining <= 0: break
		if sd.item and is_same_item(sd.item, itm) and itm.stackable:
			remaining -= min(remaining, itm.max_count - sd.amount)

	for sd in slots_list:
		if remaining <= 0: break
		if sd.item == null:
			remaining -= min(remaining, itm.max_count)

	return amount - remaining

# ── Превью предмета под курсором ──────────────────────────────────────────────
func _process(_delta: float) -> void:
	if held_preview and is_instance_valid(held_preview):
		held_preview.global_position = get_global_mouse_position() + Vector2(10, -10)

func _refresh_preview() -> void:
	_clear_preview()
	if not held_item: return

	held_preview              = Control.new()
	held_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon             = TextureRect.new()
	icon.texture         = held_item.icon
	icon.expand_mode     = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	icon.size            = Vector2(19, 19)
	icon.position        = Vector2(-8, -8)
	held_preview.add_child(icon)

	if held_amount > 1:
		var lbl = Label.new()
		lbl.text                 = str(held_amount)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
		lbl.size                 = Vector2(16, 18)
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color",         Color(1, 1, 1))
		lbl.add_theme_constant_override("outline_size",    3)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		icon.add_child(lbl)

	get_tree().get_first_node_in_group("Inventory").add_child(held_preview)
	held_preview.global_position = get_global_mouse_position() + Vector2(10, -10)

func _clear_preview() -> void:
	if held_preview and is_instance_valid(held_preview):
		held_preview.queue_free()
	held_preview = null

# ── Tooltip ───────────────────────────────────────────────────────────────────
func _on_mouse_entered() -> void:
	if item:
		var desc = item.description
		if item is equip_data:
			var dur_text = "%d / %d" % [item.get_durability(), item.max_durability]
			if item.is_broken(): dur_text += "  [СЛОМАНО]"
			desc = "DMG: %s\nRange: %s\nSpeed: %s\nПрочность: %s" % [item.Damage, item.hit_distance, item.Atk_speed, dur_text]
		elif item is FoodData:
			desc += "\nEffects:"
			for eff in item.effects:
				desc += "\n- %s: +%s (%s sec)" % [eff.effect_type, eff.value, eff.duration]
		$Tooltip.show_tooltip(item.item_name, desc)

func _on_mouse_exited() -> void:
	$Tooltip.hide_tooltip()

# ── Подсветка хотбара ─────────────────────────────────────────────────────────
func activate_slot() -> void:
	texture_normal = active_slot

func disable_slot() -> void:
	texture_normal = unactive_slot

# ── Сравнение предметов ───────────────────────────────────────────────────────
static func is_same_item(a: ItemData, b: ItemData) -> bool:
	if a == null or b == null: return false
	if a.resource_path != "" and b.resource_path != "" and a.resource_path == b.resource_path:
		return true
	return a.item_name == b.item_name and a.get_class() == b.get_class()
