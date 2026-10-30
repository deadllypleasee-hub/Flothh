class_name ScenarioEditor
extends RefCounted

const MAX_UNITS: int = 24
var scenario: Dictionary = VesselCatalog.default_scenario()
var selected: int = -1
var tool: String = "select"
var vessel_type: String = "destroyer"
var team: int = 0
var last_error: String = ""

func validate(value: Dictionary) -> bool:
	last_error = ""
	if value.get("version", 0) != 1 or not value.get("units") is Array:
		return fail("Неподдерживаемый формат сценария")
	var units: Array = value["units"]
	if units.size() > MAX_UNITS:
		return fail("Максимум %d судна" % MAX_UNITS)
	for raw: Variant in units:
		if not raw is Dictionary:
			return fail("Некорректная запись судна")
		var raw_team: Variant = raw.get("team", -1)
		if not (raw_team is int or raw_team is float):
			return fail("Некорректная команда")
		if raw.get("type", "") not in VesselCatalog.IDS or float(raw_team) not in [0.0, 1.0]:
			return fail("Неизвестный класс или команда")
		if not raw.has("x") or not raw.has("z"):
			return fail("Не заданы координаты судна")
		for key: String in ["x", "z", "heading", "speed"]:
			var number: Variant = raw.get(key, 0)
			if not (number is float or number is int) or not is_finite(float(number)):
				return fail("Некорректная координата")
		if absf(float(raw["x"])) > 4600 or absf(float(raw["z"])) > 4600:
			return fail("Судно вне границ карты")
		if absf(float(raw.get("speed", 0))) > 25:
			return fail("Некорректная начальная скорость")
		if absf(float(raw.get("heading", 0))) > 36000:
			return fail("Некорректный начальный курс")
	if not value.get("night", false) is bool:
		return fail("Параметр ночи должен быть логическим")
	if value.get("weather", "clear") not in ["clear", "storm"]:
		return fail("Неизвестная погода")
	if value.get("map", "archipelago") not in ["archipelago", "ocean"]:
		return fail("Неизвестная карта")
	if value.get("victory", "elimination") not in ["elimination", "time"]:
		return fail("Неизвестное условие победы")
	for key: String in ["waves", "wind", "ammo_scale", "time_limit", "difficulty", "player_index"]:
		var number: Variant = value.get(key, 0)
		if not (number is int or number is float) or not is_finite(float(number)):
			return fail("Некорректный параметр: " + key)
	if float(value.get("waves", 1)) < 0 or float(value.get("waves", 1)) > 6:
		return fail("Высота волн: 0–6 м")
	if float(value.get("ammo_scale", 1)) < 0 or float(value.get("ammo_scale", 1)) > 4:
		return fail("Боезапас: ×0–4")
	if float(value.get("time_limit", 900)) < 30 or float(value.get("time_limit", 900)) > 3600:
		return fail("Длительность: 30–3600 с")
	var difficulty: float = float(value.get("difficulty", 1))
	if difficulty < 0 or difficulty > 2 or difficulty != floorf(difficulty):
		return fail("Сложность ИИ: целое число 0–2")
	var player_index: float = float(value.get("player_index", 0))
	if player_index < 0 or player_index != floorf(player_index) or player_index >= maxi(1, units.size()):
		return fail("Некорректный индекс управляемого судна")
	if float(value.get("wind", 0.7)) < 0 or float(value.get("wind", 0.7)) > TAU:
		return fail("Направление ветра: 0–2π рад")
	for index: int in units.size():
		var error: String = placement_error(units[index], units, index, value.get("map", "archipelago"))
		if not error.is_empty():
			return fail("Судно №%d: %s" % [index + 1, error])
	return true

static func hull_rect(spec: Dictionary) -> Dictionary:
	var stats: Dictionary = VesselCatalog.get_stats(spec["type"])
	var heading: float = deg_to_rad(fposmod(float(spec.get("heading", 0)), 360))
	return {"center": Vector2(spec["x"], spec["z"]), "side": Vector2(cos(heading), sin(heading)),
		"forward": Vector2(sin(heading), -cos(heading)), "half": Vector2(float(stats["beam"]) * 0.5 + 3, float(stats["length"]) * 0.43 + 3)}

static func rectangles_overlap(a: Dictionary, b: Dictionary) -> bool:
	var offset: Vector2 = b["center"] - a["center"]
	for axis: Vector2 in [a["side"], a["forward"], b["side"], b["forward"]]:
		var radius_a: float = absf(axis.dot(a["side"])) * a["half"].x + absf(axis.dot(a["forward"])) * a["half"].y
		var radius_b: float = absf(axis.dot(b["side"])) * b["half"].x + absf(axis.dot(b["forward"])) * b["half"].y
		if absf(offset.dot(axis)) >= radius_a + radius_b:
			return false
	return true

static func placement_error(spec: Dictionary, units: Array, ignore: int, map_id: String) -> String:
	var hull: Dictionary = hull_rect(spec)
	if map_id == "archipelago":
		for island: Dictionary in TerrainSystem.ISLANDS:
			var offset: Vector2 = Vector2(island["x"], island["z"]) - hull["center"]
			var local: Vector2 = Vector2(offset.dot(hull["side"]), offset.dot(hull["forward"]))
			var closest: Vector2 = local.clamp(-hull["half"], hull["half"])
			if local.distance_to(closest) < float(island["radius"]) * 1.05:
				return "корпус пересекает остров"
	for index: int in units.size():
		if index != ignore and rectangles_overlap(hull, hull_rect(units[index])):
			return "корпус пересекает судно №%d" % (index + 1)
	return ""

func can_place(spec: Dictionary, ignore: int = -1) -> bool:
	last_error = placement_error(spec, scenario["units"], ignore, scenario.get("map", "archipelago"))
	return last_error.is_empty()

func fail(message: String) -> bool:
	last_error = message
	return false

func add_unit(point: Vector3) -> bool:
	if not point.is_finite():
		return fail("Некорректная точка размещения")
	if scenario["units"].size() >= MAX_UNITS:
		return fail("Достигнут лимит 24 судна")
	var spec: Dictionary = VesselCatalog.spec(vessel_type, team, clampf(point.x, -4500, 4500), clampf(point.z, -4500, 4500), 0 if team == 0 else 180)
	if not can_place(spec):
		return false
	scenario["units"].append(spec)
	selected = scenario["units"].size() - 1
	return true

func move_selected(point: Vector3) -> bool:
	if selected < 0 or selected >= scenario["units"].size():
		return fail("Сначала выберите судно")
	if not point.is_finite():
		return fail("Некорректная точка размещения")
	var candidate: Dictionary = scenario["units"][selected].duplicate(true)
	candidate["x"] = clampf(point.x, -4500, 4500)
	candidate["z"] = clampf(point.z, -4500, 4500)
	if not can_place(candidate, selected):
		return false
	scenario["units"][selected] = candidate
	return true

func rotate_selected(amount: float) -> bool:
	if selected < 0 or selected >= scenario["units"].size() or not is_finite(amount):
		return fail("Сначала выберите судно и допустимый курс")
	var candidate: Dictionary = scenario["units"][selected].duplicate(true)
	candidate["heading"] = fposmod(float(candidate.get("heading", 0)) + amount, 360)
	if not can_place(candidate, selected):
		return false
	scenario["units"][selected] = candidate
	return true

func duplicate_selected() -> bool:
	if selected < 0 or selected >= scenario["units"].size() or scenario["units"].size() >= MAX_UNITS:
		return fail("Выберите судно; лимит — 24 объекта")
	var copy: Dictionary = scenario["units"][selected].duplicate(true)
	copy["x"] = clampf(float(copy["x"]) + 170, -4500, 4500)
	if not can_place(copy):
		return false
	scenario["units"].append(copy)
	selected = scenario["units"].size() - 1
	return true

func delete_selected() -> void:
	if selected >= 0 and selected < scenario["units"].size():
		var controlled: int = int(scenario.get("player_index", 0))
		scenario["units"].remove_at(selected)
		if selected < controlled:
			controlled -= 1
		scenario["player_index"] = clampi(controlled, 0, maxi(0, scenario["units"].size() - 1))
	selected = -1

func load_scenario(value: Dictionary) -> bool:
	if not validate(value):
		return false
	scenario = value.duplicate(true)
	selected = -1
	return true
