# MerchantData.gd
extends Resource
class_name MerchantData

@export var merchant_name: String = "Торговец"
@export var merchant_icon: Texture2D
@export_multiline var greeting: String = "Добро пожаловать в мой магазин!"
@export_multiline var not_enough_money_text: String = "У вас недостаточно денег!"
@export_multiline var thank_you_text: String = "Спасибо за покупку!"

@export var buy_multiplier: float = 0.7  # Множитель цены при продаже игроком
@export var sell_multiplier: float = 1.3  # Множитель цены при покупке игроком

@export var inventory: Array[TradeItem] = []

# Предметы, которые торговец готов купить у игрока
@export var wanted_items: Array[ItemData] = []

func get_trade_item_for_item(item: ItemData) -> TradeItem:
	for trade_item in inventory:
		if trade_item.item == item:
			return trade_item
	return null

func is_item_wanted(item: ItemData) -> bool:
	return wanted_items.has(item)
