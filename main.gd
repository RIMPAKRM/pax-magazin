extends PaxMod
## Material Shop — mod code. Adds trading of dollars for resources.

# Цены в РЕАЛЬНЫХ долларах за 1 единицу ресурса
const RESOURCE_PRICES := {
	"стройматериалы": 3000.0,
	"вода": 2000.0,
	"еда": 3000.0,
	"горючее": 6000.0,
	"энергия": 1000.0,
	"нефть": 3000.0,
	"газ": 2500.0,
	"уголь": 1000.0,
	"чёрные металлы": 3000.0,
	"цветные металлы": 8000.0,
	"редкое": 10000.0,
	"лекарства": 40000.0,
	"оружие": 20000.0,
	"боеприпасы": 5000.0,
	"бронетехника": 150000.0,
	"ракеты": 250000.0,
	"дроны": 15000.0,
	"деньги": 1.0  # 1 игровая единица "денег" = 1,000,000 реальных $
}

# 1 единица денег в игровых ресурсах = 1,000,000 реальных долларов
const GAME_SCALE := 1_000_000.0

const RESOURCE_NAMES := {
	"en": {
		"стройматериалы": "Construction Materials",
		"вода": "Water",
		"еда": "Food",
		"горючее": "Fuel",
		"энергия": "Energy",
		"нефть": "Oil",
		"газ": "Gas",
		"уголь": "Coal",
		"чёрные металлы": "Ferrous Metals",
		"цветные металлы": "Non-Ferrous Metals",
		"редкое": "Rare Materials",
		"лекарства": "Medicine",
		"оружие": "Small Arms",
		"боеприпасы": "Ammunition",
		"бронетехника": "Armour",
		"ракеты": "Missiles",
		"дроны": "Drones",
		"деньги": "Dollars"
	},
	"ru": {
		"стройматериалы": "Стройматериалы",
		"вода": "Вода",
		"еда": "Еда",
		"горючее": "Горючее",
		"энергия": "Энергия",
		"нефть": "Нефть",
		"газ": "Газ",
		"уголь": "Уголь",
		"чёрные металлы": "Чёрные металлы",
		"цветные металлы": "Цветные металлы",
		"редкое": "Редкое",
		"лекарства": "Лекарства",
		"оружие": "Оружие",
		"боеприпасы": "Боеприпасы",
		"бронетехника": "Бронетехника",
		"ракеты": "Ракеты",
		"дроны": "Дроны",
		"деньги": "Доллары"
	}
}

var _dollars_label: Label
var _resource_label: Label
var _amount_label: Label
var _price_label: Label
var _resource_selector: OptionButton
var _amount_input: LineEdit
var _game_ref: PaxGame
var _selected_resource: String = "стройматериалы"


func _mod_loaded() -> void:
	log_info("Material Shop loaded")


func _world_ready(game: PaxGame) -> void:
	_game_ref = game
	game.toast(tr_key("material_shop_hello"))
	_build_ui(game)


func _days_passed(_game: PaxGame, _from_day: int, _days: int) -> void:
	_refresh_ui()


func _save_state(_game: PaxGame) -> Dictionary:
	return {"selected_resource": _selected_resource}


func _game_loaded(_game: PaxGame, state: Dictionary) -> void:
	_selected_resource = state.get("selected_resource", "стройматериалы")
	_game_ref = _game


func _build_ui(game: PaxGame) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	
	var title := Label.new()
	title.text = tr_key("material_shop_window_title")
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	
	_dollars_label = Label.new()
	box.add_child(_dollars_label)
	
	_resource_label = Label.new()
	box.add_child(_resource_label)
	
	# Выбор ресурса
	var resource_container := HBoxContainer.new()
	var resource_label := Label.new()
	resource_label.text = tr_key("material_shop_select_resource")
	resource_container.add_child(resource_label)
	
	_resource_selector = OptionButton.new()
	var lang: String = game.language()
	
	var selected_index: int = 0
	var current_index: int = 0
	
	for resource in RESOURCE_PRICES.keys():
		if resource == "деньги":
			continue
		
		var display_name: String = RESOURCE_NAMES.get(lang, RESOURCE_NAMES["en"]).get(resource, resource)
		_resource_selector.add_item(display_name)
		
		if resource == _selected_resource:
			selected_index = current_index
			
		current_index += 1
	
	_resource_selector.select(selected_index)
	_resource_selector.item_selected.connect(_on_resource_selected)
	resource_container.add_child(_resource_selector)
	box.add_child(resource_container)
	
	# Поле ввода количества
	var amount_container := HBoxContainer.new()
	var amount_label := Label.new()
	amount_label.text = tr_key("material_shop_amount")
	amount_container.add_child(amount_label)
	
	_amount_input = LineEdit.new()
	_amount_input.placeholder_text = "100000"
	_amount_input.text = "100000"
	_amount_input.text_changed.connect(_on_amount_changed)
	amount_container.add_child(_amount_input)
	box.add_child(amount_container)
	
	_price_label = Label.new()
	box.add_child(_price_label)
	
	var buy_button := Button.new()
	buy_button.text = tr_key("material_shop_buy")
	buy_button.pressed.connect(_buy_resource)
	box.add_child(buy_button)
	
	var sell_button := Button.new()
	sell_button.text = tr_key("material_shop_sell")
	sell_button.pressed.connect(_sell_resource)
	box.add_child(sell_button)
	
	game.add_window(tr_key("material_shop_button"), box, Vector2(400, 280))
	_refresh_ui()


func _refresh_ui() -> void:
	if not is_instance_valid(_dollars_label) or not is_instance_valid(_resource_label):
		return
	
	var home: String = _game_ref.home_body()
	var resources: Dictionary = _game_ref.resources(home)
	
	# Получаем сырое значение из игры (где 1 = 1,000,000$)
	var game_dollars: float = 0.0
	if not resources.is_empty():
		game_dollars = float(resources.get("деньги", 0.0))
	
	# Переводим в реальные доллары для отображения
	var real_dollars: float = game_dollars * GAME_SCALE
	_dollars_label.text = tr_key("material_shop_dollars") % _format_dollars(real_dollars)
	
	var resource_amount: float = 0.0
	if not resources.is_empty():
		resource_amount = float(resources.get(_selected_resource, 0.0))
	
	var lang: String = _game_ref.language()
	var resource_name: String = RESOURCE_NAMES.get(lang, RESOURCE_NAMES["en"]).get(_selected_resource, _selected_resource)
	_resource_label.text = tr_key("material_shop_resource_amount") % [resource_name, int(resource_amount)]
	
	_update_price()


# Принимает сумму в НАСТОЯЩИХ долларах и форматирует её
func _format_dollars(real_amount: float) -> String:
	var lang: String = "en"
	if is_instance_valid(_game_ref):
		lang = _game_ref.language()
	
	var suffix_billion: String = " млрд $" if lang == "ru" else " billion $"
	var suffix_million: String = " млн $" if lang == "ru" else " million $"
	var suffix_thousand: String = " тыс $" if lang == "ru" else " thousand $"
	
	if real_amount >= 1_000_000_000.0:
		return str(snapped(real_amount / 1_000_000_000.0, 0.01)) + suffix_billion
	elif real_amount >= 1_000_000.0:
		return str(snapped(real_amount / 1_000_000.0, 0.01)) + suffix_million
	elif real_amount >= 1_000.0:
		return str(snapped(real_amount / 1_000.0, 0.01)) + suffix_thousand
	else:
		return str(snapped(real_amount, 0.01)) + " $"


func _update_price() -> void:
	if not is_instance_valid(_price_label) or not is_instance_valid(_amount_input):
		return
	
	var amount: int = _parse_amount()
	var price_per_unit: float = RESOURCE_PRICES.get(_selected_resource, 1500.0)
	
	# Общая цена в РЕАЛЬНЫХ долларах
	var total_real_price: float = amount * price_per_unit
	_price_label.text = tr_key("material_shop_price") % [_format_dollars(total_real_price), amount]


func _parse_amount() -> int:
	var text: String = _amount_input.text if is_instance_valid(_amount_input) else "10"
	var amount: int = int(text)
	if amount <= 0:
		amount = 1
	return amount


func _on_resource_selected(index: int) -> void:
	var tradeable_resources: Array = []
	for resource in RESOURCE_PRICES.keys():
		if resource != "деньги":
			tradeable_resources.append(resource)
	
	if index >= 0 and index < tradeable_resources.size():
		_selected_resource = tradeable_resources[index]
		_refresh_ui()


func _on_amount_changed(_new_text: String) -> void:
	_update_price()


func _buy_resource() -> void:
	var amount: int = _parse_amount()
	var price_per_unit: float = RESOURCE_PRICES.get(_selected_resource, 1500.0)
	
	var total_price_real: float = amount * price_per_unit
	var total_price_game_units: float = total_price_real / GAME_SCALE
	
	var home: String = _game_ref.home_body()
	var resources: Dictionary = _game_ref.resources(home)
	if resources.is_empty():
		_game_ref.toast(tr_key("material_shop_no_colony"))
		return
	
	var game_dollars: float = float(resources.get("деньги", 0.0))
	
	if game_dollars < total_price_game_units:
		_game_ref.toast(tr_key("material_shop_no_money") % _format_dollars(total_price_real))
		return
	
	_game_ref.add_resource(home, "деньги", -total_price_game_units)
	_game_ref.add_resource(home, _selected_resource, float(amount))
	
	var lang: String = _game_ref.language()
	var resource_name: String = RESOURCE_NAMES.get(lang, RESOURCE_NAMES["en"]).get(_selected_resource, _selected_resource)
	_game_ref.toast(tr_key("material_shop_bought") % [amount, resource_name, _format_dollars(total_price_real)])
	_refresh_ui()


func _sell_resource() -> void:
	var amount: int = _parse_amount()
	var price_per_unit: float = RESOURCE_PRICES.get(_selected_resource, 1500.0)
	
	var total_price_real: float = amount * price_per_unit
	var total_price_game_units: float = total_price_real / GAME_SCALE
	
	var home: String = _game_ref.home_body()
	var resources: Dictionary = _game_ref.resources(home)
	if resources.is_empty():
		_game_ref.toast(tr_key("material_shop_no_colony"))
		return
	
	var current_amount: float = float(resources.get(_selected_resource, 0.0))
	if current_amount < float(amount):
		var lang: String = _game_ref.language()
		var resource_name: String = RESOURCE_NAMES.get(lang, RESOURCE_NAMES["en"]).get(_selected_resource, _selected_resource)
		_game_ref.toast(tr_key("material_shop_no_materials") % [resource_name])
		return
	
	_game_ref.add_resource(home, "деньги", total_price_game_units)
	_game_ref.add_resource(home, _selected_resource, -float(amount))
	
	var lang: String = _game_ref.language()
	var resource_name: String = RESOURCE_NAMES.get(lang, RESOURCE_NAMES["en"]).get(_selected_resource, _selected_resource)
	_game_ref.toast(tr_key("material_shop_sold") % [amount, resource_name, _format_dollars(total_price_real)])
	_refresh_ui()