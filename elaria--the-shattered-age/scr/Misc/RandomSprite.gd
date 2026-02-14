@tool
extends Sprite2D
class_name RandomSprite2D

@export var frame_weights :Array[float]
@export_tool_button("Randomize Sprite", "Callable")
var Randomize = func(): random_sprite()


func _ready() -> void:
	random_sprite()

func random_sprite() -> void:
	randomize()

	#if hframes > 7:
		## Добавляем равные веса для остальных кадров, если они есть
		#for i in range(2, hframes):
			#frame_weights.append(1.0)
	
	# Нормализуем веса
	var total_weight = 0.0
	for w in frame_weights:
		total_weight += w
	
	var random_value = randf() * total_weight
	var cumulative_weight = 0.0
	var selected_frame = 0
	
	for i in range(frame_weights.size()):
		cumulative_weight += frame_weights[i]
		if random_value <= cumulative_weight:
			selected_frame = i
			break
	frame = selected_frame
