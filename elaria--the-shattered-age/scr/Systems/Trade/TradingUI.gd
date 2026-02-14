# TradingUI.gd
extends Control
class_name TradingUI

@onready var merchant_name_label: Label = $Panel/MarginContainer/VBoxContainer/MerchantInfo/MerchantName
@onready var merchant_greeting_label: Label =$Panel/MarginContainer/VBoxContainer/MerchantInfo/Greeting
@onready var player_currency_label: Label = $Panel/MarginContainer/VBoxContainer/PlayerInfo/PlayerCurrency
@onready var merchant_inventory_list: ItemList = $Panel/MarginContainer/VBoxContainer/HSplitContainer/MerchantInventory
@onready var player_inventory_list: ItemList = $Panel/MarginContainer/VBoxContainer/HSplitContainer/PlayerInventory
@onready var trade_button: Button = $Panel/MarginContainer/VBoxContainer/TradeButtons/TradeButton
@onready var info_panel: Panel = $Panel/MarginContainer/VBoxContainer/InfoPanel
@onready var info_label: Label = $Panel/MarginContainer/VBoxContainer/InfoPanel/InfoLabel

var current_merchant: MerchantData
var inventory: Inventory
var selected_merchant_item: int = -1
var selected_player_item: int = -1

func _ready() -> void:
	inventory = get_tree().get_first_node_in_group("Inventory")
	info_panel.visible = false
	_setup_item_lists()

func _setup_item_lists() -> void:
	merchant_inventory_list.fixed_icon_size = Vector2(32, 32)
	player_inventory_list.fixed_icon_size = Vector2(32, 32)
	
	merchant_inventory_list.max_columns = 1
	player_inventory_list.max_columns = 1

func open_trading(merchant: MerchantData) -> void:
	current_merchant = merchant
	visible = true
	
	_update_merchant_info()
	_update_merchant_inventory()
	_update_player_inventory()
	_show_message(merchant.greeting, Color.LIGHT_BLUE)

func _update_merchant_info() -> void:
	if not current_merchant:
		return
	
	merchant_name_label.text = current_merchant.merchant_name
	merchant_greeting_label.text = current_merchant.greeting
	_update_currency_display()

func _update_currency_display() -> void:
	if not inventory or not current_merchant:
		return
	
	# Предполагаем, что первый TradeItem в инвентаре использует правильную валюту
	var currency_item = null
	if current_merchant.inventory.size() > 0:
		currency_item = current_merchant.inventory[0].currency
	
	if currency_item:
		var currency_count = inventory.get_item_count(currency_item.item_name)
		player_currency_label.text = "Ваши деньги: %d" % currency_count
	else:
		player_currency_label.text = "Ваши деньги: 0"

func _update_merchant_inventory() -> void:
	merchant_inventory_list.clear()
	
	if not current_merchant:
		return
	
	for i in range(current_merchant.inventory.size()):
		var trade_item = current_merchant.inventory[i]
		var item = trade_item.item
		var price = trade_item.price
		var stock_text = ""
		
		if trade_item.stock > 0:
			stock_text = " (Осталось: %d)" % trade_item.stock
		elif trade_item.stock == 0:
			stock_text = " (Нет в наличии)"
		
		var display_text = "%s - %d мон.%s" % [item.item_name, price, stock_text]
		merchant_inventory_list.add_item(display_text, item.icon)
		
		# Отключаем предметы, которых нет в наличии
		if trade_item.stock == 0:
			merchant_inventory_list.set_item_disabled(i, true)
			merchant_inventory_list.set_item_custom_fg_color(i, Color.GRAY)

func _update_player_inventory() -> void:
	player_inventory_list.clear()
	
	if not inventory or not current_merchant:
		return
	
	for i in range(inventory.items.size()):
		var entry = inventory.items[i]
		if entry.item and current_merchant.is_item_wanted(entry.item):
			var item = entry.item
			var amount = entry.slot.ammount
			var sell_price = calculate_sell_price(item)
			
			var display_text = "%s x%d - %d мон." % [item.item_name, amount, sell_price]
			player_inventory_list.add_item(display_text, item.icon)

func calculate_sell_price(item: ItemData) -> int:
	if not current_merchant:
		return 0
	
	var base_trade_item = current_merchant.get_trade_item_for_item(item)
	if base_trade_item:
		return int(base_trade_item.price * current_merchant.buy_multiplier)
	return int(item.quality * 5 + 10)  # Падение цены по умолчанию

func calculate_buy_price(trade_item: TradeItem) -> int:
	if not current_merchant:
		return trade_item.price
	return int(trade_item.price * current_merchant.sell_multiplier)

func _on_merchant_inventory_item_selected(index: int) -> void:
	selected_merchant_item = index
	selected_player_item = -1
	player_inventory_list.deselect_all()
	_update_trade_button()

func _on_player_inventory_item_selected(index: int) -> void:
	selected_player_item = index
	selected_merchant_item = -1
	merchant_inventory_list.deselect_all()
	_update_trade_button()

func _update_trade_button() -> void:
	if selected_merchant_item >= 0:
		var trade_item = current_merchant.inventory[selected_merchant_item]
		var price = calculate_buy_price(trade_item)
		trade_button.text = "Купить за %d мон." % price
		trade_button.disabled = false
	elif selected_player_item >= 0:
		var item_entry = _get_player_item_by_list_index(selected_player_item)
		if item_entry:
			var sell_price = calculate_sell_price(item_entry.item)
			trade_button.text = "Продать за %d мон." % sell_price
			trade_button.disabled = false
	else:
		trade_button.text = "Выберите предмет"
		trade_button.disabled = true

func _get_player_item_by_list_index(list_index: int) -> Dictionary:
	if not inventory:
		return {}
	
	var valid_items = []
	for entry in inventory.items:
		if entry.item and current_merchant.is_item_wanted(entry.item):
			valid_items.append(entry)
	
	if list_index >= 0 and list_index < valid_items.size():
		return valid_items[list_index]
	return {}

func _on_trade_button_pressed() -> void:
	if selected_merchant_item >= 0:
		_buy_from_merchant()
	elif selected_player_item >= 0:
		_sell_to_merchant()

func _buy_from_merchant() -> void:
	if selected_merchant_item < 0 or not current_merchant:
		return
	
	var trade_item = current_merchant.inventory[selected_merchant_item]
	var price = calculate_buy_price(trade_item)
	
	# Проверяем валюту
	var currency_item = trade_item.currency
	var currency_count = inventory.get_item_count(currency_item.item_name)
	
	if currency_count < price:
		_show_message(current_merchant.not_enough_money_text, Color.RED)
		return
	
	if trade_item.stock == 0:
		_show_message("Этот товар закончился!", Color.RED)
		return
	
	# Покупаем
	var amount_to_buy = trade_item.get_random_amount()
	var success = inventory.add_item(trade_item.item.duplicate(), amount_to_buy)
	
	if success:
		# Списание денег
		inventory.remove_item(currency_item, price)
		
		# Уменьшаем запас
		if trade_item.stock > 0:
			trade_item.stock -= 1
		
		_show_message(current_merchant.thank_you_text, Color.GREEN)
		print("Куплено: %s x%d за %d монет" % [trade_item.item.item_name, amount_to_buy, price])
		
		# Обновляем UI
		_update_currency_display()
		_update_merchant_inventory()
		_update_player_inventory()
		_update_trade_button()
	else:
		_show_message("Не хватает места в инвентаре!", Color.RED)

func _sell_to_merchant() -> void:
	if selected_player_item < 0 or not inventory:
		return
	
	var item_entry = _get_player_item_by_list_index(selected_player_item)
	if not item_entry or not item_entry.item:
		return
	
	var item = item_entry.item
	var sell_price = calculate_sell_price(item)
	
	# Проверяем валюту у торговца (упрощенно)
	var currency_item = null
	if current_merchant.inventory.size() > 0:
		currency_item = current_merchant.inventory[0].currency
	
	if not currency_item:
		_show_message("Торговец не может заплатить!", Color.RED)
		return
	
	# Продаем
	inventory.remove_item(item, 1)
	
	# Получаем деньги
	inventory.add_item(currency_item.duplicate(), sell_price)
	
	_show_message("Предмет продан!", Color.GREEN)
	print("Продано: %s за %d монет" % [item.item_name, sell_price])
	
	# Обновляем UI
	_update_currency_display()
	_update_merchant_inventory()
	_update_player_inventory()
	_update_trade_button()

func _show_message(text: String, color: Color) -> void:
	info_label.text = text
	info_label.modulate = color
	info_panel.visible = true
	
	# Автоматически скрываем сообщение через 3 секунды
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(_hide_message)

func _hide_message() -> void:
	info_panel.visible = false

func _on_close_button_pressed() -> void:
	visible = false
	current_merchant = null

#func _input(event: InputEvent) -> void:
	#if event.is_action_released("ui_cancel") and visible:
		#visible = false
		#current_merchant = null
