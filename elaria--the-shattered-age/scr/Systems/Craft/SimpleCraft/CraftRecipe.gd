@tool
extends Resource
class_name CraftRecipe

@export_placeholder("result item") var recipe_name: String = ""
@export_multiline var description: String = ""
@export var result_item: ItemData
@export var result_amount: int = 1
@export var crafting_time: float = 1.0
@export var required_level: int = 1

@export var ingredients: Array[CraftIngredient] = []

func can_craft(inventory: Inventory) -> bool:
	if not inventory:
		print("can_craft: inventory is null!")
		return false
		
	for ingredient in ingredients:
		var has = inventory.has_total_item(ingredient.item, ingredient.amount)
		#print("Проверка: ", ingredient.item.item_name, " нужно: ", ingredient.amount, " есть: ", inventory.get_total_item_count(ingredient.item), " → ", has)
		if not has:
			return false
	return true

func get_missing_ingredients(inventory: Inventory) -> Array[Dictionary]:
	var missing: Array[Dictionary] = []
	for ingredient in ingredients:
		var current_amount = inventory.get_total_item_count(ingredient.item)
		if current_amount < ingredient.amount:
			missing.append({
				"item": ingredient.item,
				"required": ingredient.amount,
				"current": current_amount
			})
	return missing

func get_ingredient_count() -> int:
	return ingredients.size()

func get_ingredient(index: int) -> CraftIngredient:
	if index >= 0 and index < ingredients.size():
		return ingredients[index]
	return null
