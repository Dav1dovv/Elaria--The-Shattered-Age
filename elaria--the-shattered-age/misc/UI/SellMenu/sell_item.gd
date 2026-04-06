extends HBoxContainer

signal trade_done

enum Mode { SELL, BUY }

@onready var item_texture: TextureRect = $ItemIcon
@onready var item_count_label: Label = $ItemIcon/ItemCount
@onready var price_label: Label = $PriceBox/CoinIcon/PriceLabel
@onready var action_btn: Button = $ActionButton
@onready var stock_label: Label = $StockLabel

@export var mode: Mode = Mode.SELL
@export var trade_item: ItemData
@export var trade_amount: int = 1   ## сколько предметов за одну сделку
@export var trade_price: int = 10   ## цена в Wayfinder
@export var stock: int = -1         ## -1 = бесконечно (для BUY)

const WAYFINDER = preload("uid://xyck3q0gr12o")

func _ready() -> void:
	if not trade_item:
		return
	item_texture.texture = trade_item.icon
	item_count_label.text = str(trade_amount)
	price_label.text = str(trade_price)
	action_btn.text = "SELL" if mode == Mode.SELL else "BUY"
	call_deferred("_refresh_state")

func _refresh_state() -> void:
	if not trade_item:
		return
	if not is_instance_valid(Global.inventory):
		return
	var can_trade := _can_trade()
	item_texture.modulate = Color.WHITE if can_trade else Color(0.45, 0.45, 0.45, 1.0)
	action_btn.disabled = not can_trade

	# Обновить stock
	if mode == Mode.BUY:
		if stock == -1:
			stock_label.text = "∞"
		else:
			stock_label.text = "x%d" % stock
		stock_label.visible = true
	else:
		stock_label.visible = false

func _can_trade() -> bool:
	if mode == Mode.SELL:
		return Global.inventory.has_total_item(trade_item, trade_amount)
	else:
		# BUY: хватает монет и есть в наличии
		var has_coins = Global.inventory.has_total_item(WAYFINDER, trade_price)
		var in_stock = (stock == -1 or stock > 0)
		return has_coins and in_stock

func _on_action_button_pressed() -> void:
	if not _can_trade():
		_play_shake()
		return

	if mode == Mode.SELL:
		Global.inventory.remove_from_total(trade_item, trade_amount)
		Global.pickup_item(WAYFINDER, trade_price)
	else:
		Global.inventory.remove_from_total(WAYFINDER, trade_price)
		Global.pickup_item(trade_item, trade_amount)
		if stock > 0:
			stock -= 1

	_play_success_flash()
	emit_signal("trade_done")
	_refresh_state()

# ─── Анимации ───────────────────────────────────

func _play_success_flash() -> void:
	var tween := create_tween()
	tween.tween_property(item_texture, "modulate", Color(1.4, 1.4, 0.6, 1.0), 0.08)
	tween.tween_property(item_texture, "modulate", Color.WHITE, 0.25)

func _play_shake() -> void:
	var origin := position
	var tween := create_tween()
	for i in 4:
		var offset := Vector2(6 if i % 2 == 0 else -6, 0)
		tween.tween_property(self, "position", origin + offset, 0.05)
	tween.tween_property(self, "position", origin, 0.05)

func update() -> void:
	_refresh_state()
