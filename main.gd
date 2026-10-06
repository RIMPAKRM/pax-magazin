extends PaxMod
## Material Shop — mod code. Adds trading of dollars for resources.

# Цены в РЕАЛЬНЫХ долларах за 1 единицу ресурса.
# Первый блок — виды ресурсов колонии: src/economy/Resources.gd, KINDS.
# Второй блок — товары экономики 2.0 и мирового рынка: data/market.json.
const RESOURCE_PRICES := {
	"humans": 50000.0,
	"energy": 1000.0,
	"materials": 3000.0,
	"water": 2000.0,
	"food": 3000.0,
	"fuel": 6000.0,
	"rare": 10000.0,
	"goods": 2000.0,
	"medicine": 40000.0,
	"oil": 3000.0,
	"gas": 2500.0,
	"coal": 1000.0,
	"black_metals": 3000.0,
	"colored_metals": 8000.0,
	"weapon": 20000.0,
	"ammunition": 5000.0,
	"armour": 150000.0,
	"missiles": 250000.0,
	"drones": 15000.0,
}

# Цена для ресурсов, которые игра заводит на ходу (extra: гелий-3, уран…).
const DEFAULT_PRICE := 10000.0

# Игровые ключи перевода названий ресурсов (data/lang/<code>.json игры).
const RESOURCE_LANG_KEYS := {
	"humans": "res_people",
	"energy": "res_energy",
	"materials": "res_building_materials",
	"water": "res_water",
	"food": "res_food",
	"fuel": "res_fuel",
	"rare": "material_shop_res_rare",
	"goods": "res_goods",
	"medicine": "res_medicine",
	"oil": "res_oil",
	"gas": "res_gas",
	"coal": "res_coal",
	"black_metals": "res_ferrous_metals",
	"colored_metals": "res_nonferrous_metals",
	"weapon": "res_weapon",
	"ammunition": "res_ammo",
	"armour": "res_armor",
	"missiles": "res_missiles",
	"drones": "res_drones",
}

# Ключи склада, которые ресурсами не являются (служебные секции и счётчики).
const NOT_RESOURCES := ["money", "production", "upkeep", "load", "power_consumers",
	"trust", "raw_materials", "metal", "ice"]

# Ключи ресурсов до обновления 0.25 → новые (данные сейвов игра мигрирует сама,
# но сейв мог сохраниться на старой версии мода).
const _OLD_KEYS := {
	"стройматериалы": "materials", "вода": "water", "еда": "food", "горючее": "fuel",
	"энергия": "energy", "редкое": "rare", "лекарства": "medicine", "нефть": "oil",
	"газ": "gas", "уголь": "coal", "чёрные металлы": "black_metals",
	"цветные металлы": "colored_metals", "оружие": "weapon", "боеприпасы": "ammunition",
	"бронетехника": "armour", "ракеты": "missiles", "дроны": "drones", "люди": "humans",
}

# 1 единица "money" на складе домашнего тела = 1,000,000 реальных долларов
const GAME_SCALE := 1_000_000.0

var _dollars_label: Label
var _resource_label: Label
var _price_label: Label
var _colony_selector: OptionButton
var _resource_selector: OptionButton
var _amount_input: LineEdit
var _game_ref: PaxGame
var _selected_colony: String = ""
var _selected_resource: String = "materials"
var _known_colonies: Array = []
var _known_list: Array = []


func _mod_loaded() -> void:
	log_info("Material Shop loaded")


func _world_ready(game: PaxGame) -> void:
	_game_ref = game
	game.toast(tr_key("material_shop_hello"))
	_build_ui(game)


func _days_passed(_game: PaxGame, _from_day: int, _days: int) -> void:
	_refresh_ui()


func _save_state(_game: PaxGame) -> Dictionary:
	return {"selected_resource": _selected_resource, "selected_colony": _selected_colony}


func _game_loaded(_game: PaxGame, state: Dictionary) -> void:
	_game_ref = _game
	_selected_colony = str(state.get("selected_colony", ""))
	_selected_resource = str(state.get("selected_resource", "materials"))
	# Старые сейвы могли хранить русский ключ — переводим в новый или откатываемся.
	_selected_resource = str(_OLD_KEYS.get(_selected_resource, _selected_resource))
	if not _tradeable_list().has(_selected_resource):
		_selected_resource = "materials"
	_fill_colonies()
	_fill_selector()
	_refresh_ui()


# Все ресурсы, которые можно торговать: наши + всё, что реально есть в игре
# (запас домашней колонии и объявленные extra-виды вроде гелия-3).
func _tradeable_list() -> Array:
	var list_: Array = RESOURCE_PRICES.keys()
	if _game_ref == null:
		return list_
	# Числовые ключи складов домашнего тела и выбранной колонии — кандидаты.
	var bodies: Array = [_game_ref.home_body()]
	if not _selected_colony.is_empty() and not bodies.has(_selected_colony):
		bodies.append(_selected_colony)
	for body in bodies:
		var stock: Dictionary = _game_ref.resources(str(body))
		for k in stock.keys():
			var kk := str(k)
			# Ресурсы — числа; служебные секции склада (production, upkeep, load) — словари.
			if stock[k] is Dictionary or stock[k] is Array:
				continue
			if not NOT_RESOURCES.has(kk) and not list_.has(kk):
				list_.append(kk)
	# Объявленные игрой виды с нулевым запасом (ресурс ведётся, но его ещё нет).
	if _game_ref.stock != null and _game_ref.stock.has_method("all_kinds"):
		for k in _game_ref.stock.all_kinds():
			var kk := str(k)
			if not NOT_RESOURCES.has(kk) and not list_.has(kk):
				list_.append(kk)
	return list_


# Колонии для торговли: домашнее тело первым, дальше остальные.
func _tradeable_colonies() -> Array:
	var list_: Array = []
	if _game_ref == null:
		return list_
	for c in _game_ref.colonies():
		list_.append(str(c))
	var home: String = _game_ref.home_body()
	if list_.has(home):
		list_.erase(home)
		list_.push_front(home)
	return list_


# Как показать колонию в списке: имя колонии от игры + тело («Марс»).
func _colony_display(body: String) -> String:
	if _game_ref != null and _game_ref.stock != null and _game_ref.stock.has_method("colony_name"):
		return "%s (%s)" % [str(_game_ref.stock.colony_name(body)), body]
	return body


func _fill_colonies() -> void:
	if not is_instance_valid(_colony_selector) or _game_ref == null:
		return
	var list_: Array = _tradeable_colonies()
	if list_ == _known_colonies and _colony_selector.item_count == list_.size():
		return
	_known_colonies = list_.duplicate()
	_colony_selector.clear()
	var selected_index: int = _known_colonies.find(_selected_colony)
	if selected_index < 0:
		selected_index = 0
		_selected_colony = str(_known_colonies[0]) if not _known_colonies.is_empty() else ""
	for body in _known_colonies:
		_colony_selector.add_item(_colony_display(str(body)))
	_colony_selector.select(selected_index)


func _on_colony_selected(index: int) -> void:
	if index >= 0 and index < _known_colonies.size():
		_selected_colony = str(_known_colonies[index])
		_refresh_ui()


# Название ресурса — из словаря самой игры, на языке игрока.
func _resource_name(resource: String) -> String:
	var lang_key: String = str(RESOURCE_LANG_KEYS.get(resource, "res_" + resource))
	var name_v: String = tr_key(lang_key)
	if name_v == lang_key or name_v.begins_with("res_"):
		return resource.replace("_", " ")
	return name_v


func _fill_selector() -> void:
	if not is_instance_valid(_resource_selector):
		return
	var list_: Array = _tradeable_list()
	if list_ == _known_list and _resource_selector.item_count == list_.size():
		return
	_known_list = list_.duplicate()
	_resource_selector.clear()
	var selected_index: int = _known_list.find(_selected_resource)
	if selected_index < 0:
		selected_index = 0
		_selected_resource = str(_known_list[0])
	for resource in _known_list:
		_resource_selector.add_item(_resource_name(str(resource)))
	_resource_selector.select(selected_index)


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

	# Выбор колонии
	var colony_container := HBoxContainer.new()
	var colony_label := Label.new()
	colony_label.text = tr_key("material_shop_select_colony")
	colony_container.add_child(colony_label)

	_colony_selector = OptionButton.new()
	_colony_selector.item_selected.connect(_on_colony_selected)
	colony_container.add_child(_colony_selector)
	box.add_child(colony_container)
	_fill_colonies()

	# Выбор ресурса
	var resource_container := HBoxContainer.new()
	var resource_label := Label.new()
	resource_label.text = tr_key("material_shop_select_resource")
	resource_container.add_child(resource_label)

	_resource_selector = OptionButton.new()
	_fill_selector()
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
	if not is_instance_valid(_dollars_label) or not is_instance_valid(_resource_label) or _game_ref == null:
		return

	_fill_colonies()
	_fill_selector()

	var colony: String = _current_colony()
	var resources: Dictionary = _game_ref.resources(colony)

	# Казна в игровых единицах (1 = 1,000,000$) → реальные доллары для отображения
	var game_dollars: float = _game_ref.money() if not resources.is_empty() else 0.0
	var real_dollars: float = game_dollars * GAME_SCALE
	_dollars_label.text = tr_key("material_shop_dollars") % _format_dollars(real_dollars)

	var resource_amount: float = _have_resource(colony, _selected_resource, resources)
	_resource_label.text = tr_key("material_shop_resource_amount") % [_resource_name(_selected_resource), int(resource_amount)]

	_update_price()


# Принимает сумму в НАСТОЯЩИХ долларах и форматирует её
func _format_dollars(real_amount: float) -> String:
	if real_amount >= 1_000_000_000.0:
		return tr_key("material_shop_money_billion", [snapped(real_amount / 1_000_000_000.0, 0.01)])
	elif real_amount >= 1_000_000.0:
		return tr_key("material_shop_money_million", [snapped(real_amount / 1_000_000.0, 0.01)])
	elif real_amount >= 1_000.0:
		return tr_key("material_shop_money_thousand", [snapped(real_amount / 1_000.0, 0.01)])
	else:
		return tr_key("material_shop_money_dollars", [snapped(real_amount, 0.01)])


func _update_price() -> void:
	if not is_instance_valid(_price_label) or not is_instance_valid(_amount_input):
		return

	var amount: int = _parse_amount()
	var price_per_unit: float = float(RESOURCE_PRICES.get(_selected_resource, DEFAULT_PRICE))

	# Общая цена в РЕАЛЬНЫХ долларах
	var total_real_price: float = amount * price_per_unit
	_price_label.text = tr_key("material_shop_price") % [_format_dollars(total_real_price), amount]


func _parse_amount() -> int:
	var text: String = _amount_input.text if is_instance_valid(_amount_input) else "10"
	var amount: int = int(text)
	if amount <= 0:
		amount = 1
	return amount


# Выбранная колония или домашнее тело, если выбор ещё не сделан/потерян.
func _current_colony() -> String:
	if not _selected_colony.is_empty() and _game_ref != null \
			and _game_ref.colonies().has(_selected_colony):
		return _selected_colony
	return _game_ref.home_body() if _game_ref != null else ""


# «Люди» — не складской ресурс: на домашнем теле настоящее население живёт в
# game.sim.res["humans"], а stock["humans"] — зеркало, которое игра переписывает
# из sim каждую неделю (src/sim/ColonyState.gd, extraction()). На остальных
# телах stock["humans"] — само население. Читаем через body_people (game.people),
# пишем, как colony_state().set_people().
func _have_resource(body: String, resource: String, stock: Dictionary) -> float:
	if resource == "humans":
		return _game_ref.people(body)
	return float(stock.get(resource, 0.0))


func _adjust_resource(body: String, resource: String, delta: float) -> void:
	if resource == "humans":
		var new_value: float = maxf(0.0, _game_ref.people(body) + delta)
		if body == _game_ref.home_body() and _game_ref.sim != null:
			_game_ref.sim.res["humans"] = new_value
		var z: Dictionary = _game_ref.resources(body)
		if not z.is_empty():
			z["humans"] = new_value
		return
	_game_ref.add_resource(body, resource, delta)


func _on_resource_selected(index: int) -> void:
	if index >= 0 and index < _known_list.size():
		_selected_resource = str(_known_list[index])
		_refresh_ui()


func _on_amount_changed(_new_text: String) -> void:
	_update_price()


func _buy_resource() -> void:
	if _game_ref == null:
		return

	var colony: String = _current_colony()
	if colony.is_empty() or _game_ref.resources(colony).is_empty():
		_game_ref.toast(tr_key("material_shop_no_colony"))
		return

	var amount: int = _parse_amount()
	var price_per_unit: float = float(RESOURCE_PRICES.get(_selected_resource, DEFAULT_PRICE))

	var total_price_real: float = amount * price_per_unit
	var total_price_game_units: float = total_price_real / GAME_SCALE

	if _game_ref.money() < total_price_game_units:
		_game_ref.toast(tr_key("material_shop_no_money", [_format_dollars(total_price_real)]))
		return

	_game_ref.add_money(-total_price_game_units)
	_adjust_resource(colony, _selected_resource, float(amount))

	_game_ref.toast(tr_key("material_shop_bought", [amount, _resource_name(_selected_resource), _format_dollars(total_price_real)]))
	_refresh_ui()


func _sell_resource() -> void:
	if _game_ref == null:
		return

	var colony: String = _current_colony()
	var resources: Dictionary = _game_ref.resources(colony)
	if colony.is_empty() or resources.is_empty():
		_game_ref.toast(tr_key("material_shop_no_colony"))
		return

	var amount: int = _parse_amount()
	var price_per_unit: float = float(RESOURCE_PRICES.get(_selected_resource, DEFAULT_PRICE))

	var total_price_real: float = amount * price_per_unit
	var total_price_game_units: float = total_price_real / GAME_SCALE

	var current_amount: float = _have_resource(colony, _selected_resource, resources)
	if current_amount < float(amount):
		_game_ref.toast(tr_key("material_shop_no_materials", [_resource_name(_selected_resource)]))
		return

	_game_ref.add_money(total_price_game_units)
	_adjust_resource(colony, _selected_resource, -float(amount))

	_game_ref.toast(tr_key("material_shop_sold", [amount, _resource_name(_selected_resource), _format_dollars(total_price_real)]))
	_refresh_ui()
