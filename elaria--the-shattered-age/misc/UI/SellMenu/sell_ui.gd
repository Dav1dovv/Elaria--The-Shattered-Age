extends Panel

const SELL_ITEM_SCENE = preload("uid://v8iejh66poru")
const WAYFINDER = preload("uid://xyck3q0gr12o")

@onready var company_logo_texture: TextureRect = $VBox/Header/CompanyLogo
@onready var trader_name_label: Label = $VBox/Header/HeaderInfo/TraderName
@onready var rep_bar: ProgressBar = $VBox/RepRow/RepBar
@onready var rep_label: Label = $VBox/RepRow/RepLabel
@onready var rep_level_label: Label = $VBox/Header/HeaderInfo/RepLevelLabel
@onready var sell_container: VBoxContainer = $VBox/SellScroll/SellContainer
@onready var buy_container: VBoxContainer = $VBox/BuyScroll/BuyContainer
@onready var sell_tab_btn: Button = $VBox/TabRow/SellTabBtn
@onready var buy_tab_btn: Button = $VBox/TabRow/BuyTabBtn
@onready var sell_scroll: ScrollContainer = $VBox/SellScroll
@onready var buy_scroll: ScrollContainer = $VBox/BuyScroll
@onready var level_up_popup: Label = $LevelUpPopup

@export var trader: TraderData

var rep_points: int = 0
var rep_level: int = 1
var _is_ready: bool = false

func _ready() -> void:
	if not trader:
		push_error("sell_ui: нет TraderData!")
		return

	company_logo_texture.texture = trader.company_logo
	trader_name_label.text = trader.trader_name
	level_up_popup.modulate.a = 0.0

	_update_rep_bar()
	_rebuild_lists()
	_show_tab("sell")
	_is_ready = true

# ─── Табы ────────────────────────────────────────

func _on_sell_tab_btn_pressed() -> void:
	_show_tab("sell")

func _on_buy_tab_btn_pressed() -> void:
	_show_tab("buy")

func _show_tab(tab: String) -> void:
	sell_scroll.visible = tab == "sell"
	buy_scroll.visible = tab == "buy"
	sell_tab_btn.button_pressed = tab == "sell"
	buy_tab_btn.button_pressed = tab == "buy"

# ─── Репутация ───────────────────────────────────

func _update_rep_bar() -> void:
	var old_level := rep_level

	# Определить текущий уровень и прогресс
	var next_threshold: int
	if rep_points < trader.rep_to_lvl2:
		rep_level = 1
		rep_bar.max_value = trader.rep_to_lvl2
		rep_bar.value = rep_points
		next_threshold = trader.rep_to_lvl2
	elif rep_points < trader.rep_to_lvl3:
		rep_level = 2
		rep_bar.max_value = trader.rep_to_lvl3 - trader.rep_to_lvl2
		rep_bar.value = rep_points - trader.rep_to_lvl2
		next_threshold = trader.rep_to_lvl3
	else:
		rep_level = 3
		rep_bar.max_value = 1
		rep_bar.value = 1
		next_threshold = trader.rep_to_lvl3

	rep_label.text = "%d / %d" % [rep_points, next_threshold] if rep_level < 3 else "MAX"
	rep_level_label.text = "Lvl %d" % rep_level

	if rep_level > old_level:
		_play_level_up(rep_level)
		_rebuild_lists()

func _play_level_up(new_lvl: int) -> void:
	level_up_popup.text = "🔓 Уровень %d — новые товары!" % new_lvl
	var tween := create_tween()
	tween.tween_property(level_up_popup, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.8)
	tween.tween_property(level_up_popup, "modulate:a", 0.0, 0.4)

# ─── Список товаров ──────────────────────────────

func _rebuild_lists() -> void:
	for c in sell_container.get_children():
		c.queue_free()
	for c in buy_container.get_children():
		c.queue_free()

	# SELL — что торговец покупает у игрока
	for entry in trader.buy_entries:
		if not entry or not entry.item:
			continue
		if entry.required_rep_level <= rep_level:
			var row := SELL_ITEM_SCENE.instantiate()
			row.mode = row.Mode.SELL
			row.trade_item = entry.item
			row.trade_amount = trader.get_buy_amount(rep_level)
			row.trade_price = trader.get_buy_price(entry.price, rep_level)
			row.stock = -1
			row.connect("trade_done", _on_trade_done.bind(row.Mode.SELL))
			sell_container.add_child(row)

	# BUY — что торговец продаёт игроку
	for entry in trader.sell_entries:
		if not entry or not entry.item:
			continue
		if entry.required_rep_level <= rep_level:
			var row := SELL_ITEM_SCENE.instantiate()
			row.mode = row.Mode.BUY
			row.trade_item = entry.item
			row.trade_amount = 1
			row.trade_price = entry.price
			row.stock = entry.resolve_stock()
			row.connect("trade_done", _on_trade_done.bind(row.Mode.BUY))
			buy_container.add_child(row)

# ─── Реакция на сделку ───────────────────────────

func _on_trade_done(mode) -> void:
	# Репутация растёт при продаже
	if mode == 0: # SELL
		rep_points += 1
		_update_rep_bar()
	_refresh_all_rows()

func _refresh_all_rows() -> void:
	if not _is_ready:
		return
	for c in sell_container.get_children():
		if c.has_method("update"):
			c.update()
	for c in buy_container.get_children():
		if c.has_method("update"):
			c.update()

func _on_visibility_changed() -> void:
	if not _is_ready:
		return
	_refresh_all_rows()
