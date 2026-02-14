## MerchantAI.gd
## Тонкая надстройка над UniversalAI для торговца.
## В config выбери тип MERCHANT и заполни merchant_data.

extends UniversalAI
class_name MerchantAI

@onready var trading_ui: CanvasLayer = $CanvasLayer
@onready var interaction: interaction_area = $Interaction

func _ready() -> void:
	super._ready()
	if interaction:
		interaction.interact = Callable(self, "_interact")

func _interact() -> void:
	if trading_ui == null:
		return
	trading_ui.visible = !trading_ui.visible
	var ui = trading_ui.get_node_or_null("TradingUi")
	if ui and config.merchant_data:
		ui.visible = true
		ui.open_trading(config.merchant_data)
