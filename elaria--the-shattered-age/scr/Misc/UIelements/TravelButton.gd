extends blaze_button
class_name travel_button

enum planets {Oktavia, Melaris, Vehana}

@export var planet_button : planets = planets.Oktavia
@export var is_comming_soon : bool = false
@onready var explore_progess: ProgressBar = %ExploreProgress

@export var planet_sprites : AtlasTexture

func _ready() -> void:
	if is_comming_soon:
		disabled = true
		if $Label:
			$Label.visible = true
	match planet_button:
		planets.Oktavia:
			text = "Oktavia"
			icon = planet_sprites
			
		planets.Melaris:
			text = "Melaris"
			icon = planet_sprites

		planets.Vehana:
			text = "Vehana"
			icon = planet_sprites


func _pressed() -> void:
	match planet_button:
		planets.Oktavia:
			Global.scene_manager.change_scene("oktavia",true,Vector2.ZERO)
