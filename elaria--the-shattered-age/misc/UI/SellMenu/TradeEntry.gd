extends Resource
class_name TradeEntry

@export var item: ItemData
@export var price: int = 10
## -1 = бесконечно, -2 = случайное (от random_stock_min до random_stock_max)
@export var stock: int = -1
@export var random_stock_min: int = 1
@export var random_stock_max: int = 5
@export var required_rep_level: int = 1  ## 1, 2 или 3

func resolve_stock() -> int:
	if stock == -2:
		return randi_range(random_stock_min, random_stock_max)
	return stock
