extends Resource
class_name TraderData

@export var trader_name: String = "Trader"
@export var company_logo: Texture2D
@export var rep_to_lvl2: int = 10   ## сколько продаж до lvl2
@export var rep_to_lvl3: int = 25   ## сколько продаж до lvl3
@export var buy_entries: Array[TradeEntry] = []   ## что торговец ПОКУПАЕТ у игрока
@export var sell_entries: Array[TradeEntry] = []  ## что торговец ПРОДАЁТ игроку

## Бонусы за уровень репутации (применяются к buy_entries)
@export_group("Reputation Bonuses")
@export var price_discount_per_level: float = 0.015  ## скидка на цену за уровень (0.015 = 1.5%)
@export var amount_per_level: Array[int] = [1, 3, 6]  ## сколько покупает на lvl1/lvl2/lvl3

## Возвращает итоговую цену с учётом уровня репутации
func get_buy_price(base_price: int, rep_level: int) -> int:
	var discount := price_discount_per_level * (rep_level - 1)
	return maxi(1, roundi(base_price * (1.0 - discount)))

## Возвращает количество которое торговец купит за раз
func get_buy_amount(rep_level: int) -> int:
	var idx := clampi(rep_level - 1, 0, amount_per_level.size() - 1)
	return amount_per_level[idx]
