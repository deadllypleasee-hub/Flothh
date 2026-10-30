class_name MissionManager
extends RefCounted

signal finished(success: bool, message: String)
const TITLES: Array[String] = ["Первый выход из порта", "Управление эсминцем", "Навигация по маршруту", "Швартовка", "Спасательная операция", "Патрулирование", "Первое погружение", "Работа с сонаром", "Сопровождение конвоя", "Учебное морское сражение"]
const BRIEFS: Array[String] = [
	"Пройдите 350 м от места старта. W/S — телеграф, A/D — руль.",
	"Разгонитесь до 12 узлов и измените курс на 60°.",
	"Посетите три навигационные точки. Назначайте маршрут на карте.",
	"Подойдите к янтарному маркеру порта ближе 140 м со скоростью менее 2 узлов.",
	"Удерживайтесь в 120 м от спасательного буя 8 секунд, скорость менее 4 узлов.",
	"Посетите три точки патруля. Можно включить автопилот через карту.",
	"На подлодке погрузитесь на 20 м, затем всплывите до 2 м.",
	"Погрузитесь глубже 8 м и обнаружьте подводный контакт. Нажмите «Сонар».",
	"Оставайтесь в 650 м от союзного транспорта 60 секунд. Защитите его.",
	"Потопите все обнаруженные вражеские суда. Ракеты — надводные, торпеды — подводные."]
var active: int = -1
var elapsed: float = 0
var initial_heading: float = 0
var stage: int = 0
var hold: float = 0
var done: bool = false
var marker: Vector3 = Vector3.ZERO
var status: String = ""
var world: GameManager

func start(index: int, game: GameManager) -> void:
	active = clampi(index, 0, 9)
	world = game
	elapsed = 0
	stage = 0
	hold = 0
	done = false
	initial_heading = world.player.heading_degrees()
	marker = Vector3(0, 0, -350)
	if active == 3:
		marker = world.terrain.port_position + Vector3(160, 0, 0)
	status = BRIEFS[active]

func tick(delta: float) -> void:
	if active < 0 or done or world == null:
		return
	elapsed += delta
	var ship: ShipController = world.player
	if not is_instance_valid(ship) or ship.damage.sinking:
		finish(false, "Управляемое судно потеряно")
		return
	if elapsed > 900:
		finish(false, "Истекло время задания")
		return
	var distance: float = Vector2(ship.position.x - marker.x, ship.position.z - marker.z).length()
	var success: bool = false
	match active:
		0: success = ship.distance_travelled >= 350
		1: success = absf(ship.speed) >= 6.17 and absf(angle_difference(deg_to_rad(initial_heading), deg_to_rad(ship.heading_degrees()))) >= PI / 3
		2, 5:
			if distance < 130:
				stage += 1
				marker = Vector3(350 if stage == 1 else -200, 0, -350 - stage * 300)
			status = "Точки: %d / 3 · следующая на карте" % stage
			success = stage >= 3
		3: success = distance < 140 and absf(ship.speed) < 1.03
		4:
			hold = hold + delta if distance < 120 and absf(ship.speed) < 2.06 else 0
			status = "Спасение: %.0f / 8 с · подойдите к янтарному маркеру" % hold
			success = hold >= 8
		6:
			if ship.get_depth() >= 20:
				stage = 1
			status = "Теперь всплывите до 2 м" if stage == 1 else "Погрузитесь на 20 м"
			success = stage == 1 and ship.get_depth() < 2
		7: success = ship.get_depth() > 8 and world.sonar_used and world.nearest_detected_enemy(ship) != null
		8:
			if world.ships.size() > 1:
				var transport: ShipController = world.ships[1]
				if transport.damage.sinking:
					finish(false, "Транспорт потерян")
					return
				hold = hold + delta if ship.position.distance_to(transport.position) < 650 else hold
				status = "Сопровождение: %.0f / 60 с" % hold
				success = hold >= 60
		9: success = world.alive_count(1) == 0
	if success:
		finish(true, "Задание выполнено · +%d кредитов" % (1500 + active * 350))

func finish(success: bool, message: String) -> void:
	if done:
		return
	done = true
	if success:
		world.economy.reward(active, 1500 + active * 350)
	finished.emit(success, message)
