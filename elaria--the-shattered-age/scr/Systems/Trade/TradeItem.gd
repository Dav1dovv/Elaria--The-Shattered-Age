# TradeItem.gd
extends Resource
class_name TradeItem

@export var item: ItemData
@export var price: int = 10
## Предмет, используемый как валюта (например, золотые монеты)
@export var currency: ItemData  
@export var min_amount: int = 1
@export var max_amount: int = 1
## -1 = бесконечный запас
@export var stock: int = -1  
## Время пополнения в секундах
@export var restock_time: float = 300.0  

func get_random_amount() -> int:
	if min_amount == max_amount:
		return min_amount
	return randi_range(min_amount, max_amount)
