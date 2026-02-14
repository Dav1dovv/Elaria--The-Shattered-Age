@icon("res://common/icons/helpcon2.png")
extends Resource
class_name ItemData

@export var icon : Texture
@export_enum("Attack","Eating","Drink","Shoot") var play_anim : String = "Attack"
@export_placeholder("Wood,Stone,Clay") var item_name : String
@export_multiline var description : String
@export var count : int 
@export var max_count : int = 64
@export var stackable : bool = true
## 0:"common",1: "rare",2:"magic",3:"mythic",4:"epic",5:"legendary") 
@export var quality: int = 0  

# Базовый метод для применения качества (переопределяй в подклассах)
func apply_quality_multiplier(q: int) -> void:
	#quality = q
	## Базовая логика: добавляем в описание
	var quality_names = ["Common", "Rare", "Epic"]
	description += "\n(Quality: " + quality_names[q] + ")" if not description.contains("Quality:") else ""
	print("Applied quality ", q, " to ", item_name)
