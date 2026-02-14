extends Panel

@onready var day: Label = $VBoxContainer/VBoxContainer/Day
@onready var location: Label = $VBoxContainer/VBoxContainer/Location
@onready var note: AutoSizeLabel = $VBoxContainer/VBoxContainer/Note

var seasons: Array[String] = ["Yanuaris","Kardus","Tirena","Vallis","Lira","Eikhon","Verda","Morva"]

func _ready() -> void:
	day.text = "Day: " + str(Global.day_night.current_day) + "\n Season: " + seasons[Global.day_night.current_season]
	location.text = "Location: " + Global.current_location
	Global.day_night.day_changed.connect(update_info)

func update_info():
	day.text = "Day: " + str(Global.day_night.current_day) + "\n Season: " + seasons[Global.day_night.current_season]
	location.text = "Location: " + Global.current_location
