extends blaze_button
class_name travel_button

enum planets {Oktavia, Melaris, Vehana}

@export var planet_button : planets = planets.Oktavia
@onready var explore_progess: ProgressBar = %ExploreProgress

@export var planet_sprites : AtlasTexture

func _ready() -> void:
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

	explore_progess.value = Global.explored_progress

func _pressed() -> void:
	match planet_button:
		planets.Oktavia:
			Global.scene_manager.change_scene("oktavia",true,Vector2.ZERO)
