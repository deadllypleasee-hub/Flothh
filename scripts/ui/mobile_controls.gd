class_name MobileControls
extends Control
## Fixed design canvas fitted to the available landscape area; all controls >= 44 px.
const INK: Color = Color("dce9ee")
const MUTED: Color = Color("92aab8")
const GOLD: Color = Color("e8b76a")
const TEAL: Color = Color("55d4d0")
var world: GameManager
var root: Control
var screen: Control
var modal: Control
var modal_visible: bool = false
var wheel: VirtualWheel
var throttle_slider: VSlider
var map_view: TacticalMap
var map_overlay: Control
var status_label: Label
var combat_label: Label
var mission_label: Label
var log_label: Label
var depth_label: Label
var map_info: Label
var toast: String = ""
var toast_time: float = 0
var tick: float = 0
var editor_info: Label
var preview: bool = false
var hidden_ui: bool = false
var append_route: bool = false
var append_route_button: CheckButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme: Theme = Theme.new()
	theme.default_font_size = 16
	var normal: StyleBoxFlat = style(Color(0.04, 0.10, 0.15, 0.95), Color("355263"))
	var hover: StyleBoxFlat = style(Color("1a3b4b"), TEAL)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", style(Color("25515b"), GOLD))
	theme.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), GOLD))
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_color", "Label", INK)
	self.theme = theme
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(1280, 720)
	add_child(root)

func style(fill: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box

func place(node: Control, parent: Control, x: float, y: float, w: float, h: float) -> void:
	parent.add_child(node)
	node.position = Vector2(x, y)
	node.size = Vector2(w, h)

func label(parent: Control, value: String, x: float, y: float, w: float = 300, h: float = 30, font_size: int = 16, color: Color = INK) -> Label:
	var item: Label = Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(item, parent, x, y, w, h)
	return item

func button(parent: Control, value: String, action: Callable, x: float, y: float, w: float = 170, h: float = 46) -> Button:
	var item: Button = Button.new()
	item.text = value
	item.pressed.connect(action)
	place(item, parent, x, y, w, h)
	return item

func panel(parent: Control, x: float, y: float, w: float, h: float, alpha: float = 0.93) -> Panel:
	var item: Panel = Panel.new()
	item.add_theme_stylebox_override("panel", style(Color(0.025, 0.065, 0.105, alpha), Color("2a4758")))
	place(item, parent, x, y, w, h)
	return item

func option(parent: Control, values: Array, x: float, y: float, w: float = 300) -> OptionButton:
	var item: OptionButton = OptionButton.new()
	for value: Variant in values:
		item.add_item(str(value))
	place(item, parent, x, y, w, 44)
	return item

func clear_screen() -> void:
	close_modal()
	if screen != null:
		root.remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	status_label = null
	combat_label = null
	mission_label = null
	log_label = null
	depth_label = null
	map_info = null
	editor_info = null
	map_overlay = null
	map_view = null
	append_route = false
	append_route_button = null
	throttle_slider = null
	modal_visible = false
	hidden_ui = false

func show_menu() -> void:
	clear_screen()
	panel(screen, 28, 28, 640, 664, 0.80)
	label(screen, "■  F O R T I S   G A M E S", 58, 52, 500, 28, 15, GOLD)
	label(screen, "FORTIS", 54, 96, 580, 106, 86)
	label(screen, "D E E P   W A T E R S", 60, 205, 570, 48, 25, TEAL)
	label(screen, "ОКЕАН ПОД ВАШИМ КОМАНДОВАНИЕМ", 60, 270, 560, 32, 15, MUTED)
	button(screen, "Кампания", show_missions.bind(false), 60, 336, 270)
	button(screen, "Свободное плавание", show_free_select, 350, 336, 270)
	button(screen, "Быстрый бой", func() -> void: world.start_battle(VesselCatalog.default_scenario()), 60, 396, 270)
	button(screen, "Редактор сражений", world.open_editor, 350, 396, 270)
	button(screen, "Наблюдатель", func() -> void: world.start_battle(VesselCatalog.default_scenario(), true), 60, 456, 270)
	button(screen, "Обучение", show_missions.bind(true), 350, 456, 270)
	button(screen, "Военно-морская база", show_base, 60, 516, 270)
	button(screen, "Настройки", show_settings, 350, 516, 270)
	label(screen, "ОФЛАЙН  /  3D SANDBOX  /  ПРОТОТИП 0.1.1", 60, 608, 570, 30, 13, MUTED)
	label(screen, "Godot 4.6.3 · все корабли и вооружение вымышлены", 60, 644, 570, 26, 12, MUTED)
	var card: Panel = panel(screen, 880, 500, 365, 165, 0.86)
	label(card, "01 / ГЛУБОКИЕ ВОДЫ", 22, 16, 320, 28, 16, GOLD)
	label(card, "11 судов. Шторм. Ночь.\nСоздайте собственный бой\nили возьмите командование флотом.", 22, 54, 320, 90, 17)

func new_modal(title: String, w: float = 760, h: float = 560) -> Panel:
	close_modal()
	modal = Control.new()
	modal.size = Vector2(1280, 720)
	root.add_child(modal)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0.02, 0.04, 0.80)
	place(shade, modal, 0, 0, 1280, 720)
	var box: Panel = panel(modal, (1280 - w) / 2, (720 - h) / 2, w, h)
	label(box, title, 24, 18, w - 110, 40, 24, GOLD)
	button(box, "×", dismiss_modal, w - 66, 16, 44, 44)
	modal_visible = true
	return box

func close_modal() -> void:
	if modal != null:
		root.remove_child(modal)
		modal.queue_free()
		modal = null
	modal_visible = map_overlay != null and map_overlay.visible

func dismiss_modal() -> void:
	if get_tree().paused:
		get_tree().paused = false
	close_modal()

func show_missions(training: bool) -> void:
	var box: Panel = new_modal("Обучение" if training else "Кампания · задания", 900, 630)
	for i: int in 10:
		var row: int = i / 2
		var col: int = i % 2
		var unlocked: bool = training or i == 0 or (i - 1) in world.economy.completed
		var caption: String = "%02d  %s%s" % [i + 1, MissionManager.TITLES[i], " ✓" if i in world.economy.completed else ""]
		var item: Button = button(box, caption, world.start_mission.bind(i), 24 + col * 434, 86 + row * 90, 414, 52)
		item.disabled = not unlocked
		label(box, "Награда %d · лимит 15 минут" % (1500 + i * 350), 28 + col * 434, 141 + row * 90, 410, 24, 12, MUTED)

func show_free_select() -> void:
	var box: Panel = new_modal("Выберите судно · свободное плавание", 760, 320)
	var picker: OptionButton = option(box, VesselCatalog.NAMES, 30, 94, 700)
	picker.select(3)
	var info: Label = label(box, "Открытые суда доступны на базе. В редакторе доступны все классы.", 30, 156, 700, 35, 14, MUTED)
	button(box, "Выйти в море", func() -> void:
		var id: String = VesselCatalog.IDS[picker.selected]
		if id in world.economy.unlocked:
			world.start_free(id)
		else:
			info.text = "Сначала откройте это судно на базе.", 30, 222, 700)

func show_settings() -> void:
	var box: Panel = new_modal("Настройки", 700, 480)
	label(box, "Качество графики", 30, 92)
	var quality: OptionButton = option(box, ["Низкое", "Среднее", "Высокое"], 340, 86, 320)
	quality.select(int(world.economy.settings.get("quality", 1)))
	quality.item_selected.connect(func(index: int) -> void:
		world.apply_quality(index)
		world.economy.save())
	var sound: CheckButton = CheckButton.new()
	sound.text = "Пространственные звуки"
	sound.button_pressed = bool(world.economy.settings.get("sound", true))
	place(sound, box, 30, 156, 620, 48)
	sound.toggled.connect(func(enabled: bool) -> void:
		world.economy.settings["sound"] = enabled
		world.effects.audio_enabled = enabled
		world.economy.save())
	label(box, "Камера: жест по свободной области / правая кнопка мыши.\nW/S — ход · A/D — руль · T — цель · Пробел — огонь\nM — карта · Tab — судно · C — камера · [ / ] — глубина\n1 / 2 / 3 — орудие / ракета / торпеда", 30, 235, 640, 125, 15, MUTED)
	button(box, "Лицензии движка", show_licenses, 30, 390, 630)

func show_licenses() -> void:
	var box: Panel = new_modal("Лицензии · Godot Engine", 900, 620)
	var text: TextEdit = TextEdit.new()
	text.editable = false
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.text = Engine.get_license_text()
	place(text, box, 24, 84, 852, 510)

func show_base() -> void:
	var box: Panel = new_modal("Военно-морская база", 1000, 640)
	label(box, "%d кредитов · репутация %d" % [world.economy.credits, world.economy.reputation], 28, 70, 900, 32, 19, TEAL)
	for i: int in 9:
		var id: String = VesselCatalog.IDS[i]
		var open: bool = id in world.economy.unlocked
		var item: Button = button(box, VesselCatalog.NAMES[i] + (" · открыто" if open else " · %d" % VesselCatalog.get_stats(id)["price"]), func() -> void:
			world.economy.unlock(id)
			show_base(), 28 + (i % 2) * 480, 122 + (i / 2) * 62, 455, 48)
		item.disabled = open
	for i: int in 3:
		var kind: String = ["engine", "sensors", "defense"][i]
		var caption: String = ["Двигатель", "Приборы", "Защита"][i]
		button(box, "%s %d/3 · %d" % [caption, world.economy.upgrades[kind], 3500 * (int(world.economy.upgrades[kind]) + 1)], func() -> void:
			world.economy.upgrade(kind)
			show_base(), 28 + i * 320, 458, 300, 48)
	label(box, "Улучшения применяются при следующем выходе в свободное плавание или миссию.\nРемонт и пополнение боезапаса доступны с боевого поста в порту.", 28, 540, 940, 65, 15, MUTED)

func show_game() -> void:
	clear_screen()
	var top: Panel = panel(screen, 20, 16, 980, 80, 0.85)
	status_label = label(top, "", 18, 8, 940, 32, 20)
	depth_label = label(top, "", 18, 43, 940, 26, 14, TEAL)
	button(screen, "Ⅱ", toggle_pause, 1208, 16, 52, 52)
	button(screen, "КАРТА", toggle_map, 1100, 16, 96, 52)
	var mini: TacticalMap = TacticalMap.new()
	mini.world = world
	mini.mini = true
	place(mini, screen, 1040, 88, 220, 174)
	mission_label = label(screen, "", 30, 110, 850, 62, 16, GOLD)
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label = label(screen, "", 30, 195, 940, 84, 14, MUTED)
	var bottom: Panel = panel(screen, 20, 486, 1240, 216, 0.85)
	wheel = VirtualWheel.new()
	place(wheel, bottom, 12, 26, 166, 166)
	label(bottom, "РУЛЬ", 68, 0, 100, 30, 12, MUTED)
	throttle_slider = VSlider.new()
	throttle_slider.min_value = -100
	throttle_slider.max_value = 100
	throttle_slider.step = 5
	throttle_slider.value = world.player.throttle * 100 if world.player != null else 0
	place(throttle_slider, bottom, 205, 35, 44, 160)
	throttle_slider.value_changed.connect(func(value: float) -> void:
		if world.player != null and not world.spectator.active:
			world.player.autopilot = false
			world.player.throttle = value / 100)
	label(bottom, "ХОД", 203, 0, 70, 30, 12, MUTED)
	button(bottom, "СТОП", func() -> void:
		throttle_slider.value = 0
		world.player.autopilot = false, 276, 151, 88)
	button(bottom, "Камера", cycle_camera, 276, 32, 132)
	button(bottom, "Судно", world.next_ship, 276, 91, 132)
	button(bottom, "−10 м", change_depth.bind(-10.0), 424, 32, 104)
	button(bottom, "+10 м", change_depth.bind(10.0), 538, 32, 104)
	button(bottom, "Авар. всплытие", emergency_surface, 424, 91, 218)
	button(bottom, "Сонар", sonar, 424, 151, 104)
	button(bottom, "Экипаж", show_crew, 538, 151, 104)
	var weapons: OptionButton = option(bottom, ["Орудие", "Ракета", "Торпеда"], 668, 32, 220)
	weapons.select(["gun", "missile", "torpedo"].find(world.selected_weapon))
	weapons.item_selected.connect(func(index: int) -> void: world.selected_weapon = ["gun", "missile", "torpedo"][index])
	button(bottom, "Выбрать цель", world.cycle_target, 668, 91, 220)
	button(bottom, "Свободный прицел", func() -> void: world.player.target = null, 668, 151, 220)
	button(bottom, "О Г О Н Ь", world.fire_player, 912, 32, 298, 72).add_theme_color_override("font_color", GOLD)
	combat_label = label(bottom, "", 916, 112, 300, 88, 14)
	button(screen, "ПОЛЁТ", func() -> void: world.camera_manager.set_mode(5), 1110, 280, 150)
	button(screen, "Наблюдатель", func() -> void:
		world.spectator.enter()
		world.log_event("Наблюдатель: штурвал перемещает свободную камеру"), 1110, 338, 150)
	button(screen, "×1 / ×2 / ×4", func() -> void:
		var current: float = world.spectator.time_scale
		world.spectator.set_speed(1 if current >= 4 else current * 2), 1110, 396, 150)
	button(screen, "Скрыть HUD", toggle_ui, 920, 424, 150)
	build_map_overlay()

func cycle_camera() -> void:
	world.camera_manager.set_mode((world.camera_manager.mode + 1) % 7)
	world.log_event("Камера: " + CameraManager.MODES[world.camera_manager.mode])

func change_depth(amount: float) -> void:
	if world.player is SubmarineController and not world.spectator.active:
		(world.player as SubmarineController).change_depth(amount)

func emergency_surface() -> void:
	if world.player is SubmarineController:
		(world.player as SubmarineController).emergency_surface()

func sonar() -> void:
	world.sonar_used = true
	world.update_detection()
	world.effects.play_sound("sonar", world.player.global_position)
	world.log_event("Сонар: контактов противника %d" % (world.detected[0].size() - world.alive_count(0)))

func show_crew() -> void:
	var box: Panel = new_modal("Боевой пост · экипаж и аварийные службы", 820, 470)
	var ship: ShipController = world.player
	label(box, "Капитан — управление   ·   Штурман — маршрут\nМеханик — механизмы   ·   Радар / Сонар — обнаружение\nОфицер вооружения — огонь   ·   Ремонтная команда — аварии", 28, 78, 760, 100, 16, MUTED)
	label(box, "Мораль %.0f%% · эффективность %.0f%%\nПожар %.0f%% · вода %.0f%% · двигатель %.0f%% · радар %.0f%%" % [ship.crew.morale * 100, ship.crew.efficiency * 100, ship.damage.fire * 100, ship.damage.flooding * 100, ship.damage.engine * 100, ship.damage.radar * 100], 28, 192, 760, 65, 18)
	button(box, "Ремонт", func() -> void: ship.crew.order("repair"), 28, 288, 238)
	button(box, "Тушить пожар", func() -> void: ship.crew.order("fire"), 288, 288, 238)
	button(box, "Откачать воду", func() -> void: ship.crew.order("pump"), 548, 288, 238)
	button(box, "Обслуживание в порту", func() -> void:
		if ship.global_position.distance_to(world.terrain.port_position) < 350 and absf(ship.speed) < 1.03 and not ship.damage.sinking:
			world.log_event("Судно обслужено" if world.economy.service(ship) else "Недостаточно кредитов")
		else:
			world.log_event("Подойдите к порту ближе 350 м и остановитесь")
		close_modal(), 28, 366, 758)

func build_map_overlay() -> void:
	map_overlay = Control.new()
	map_overlay.size = Vector2(1280, 720)
	screen.add_child(map_overlay)
	panel(map_overlay, 14, 14, 1252, 692, 1.0)
	label(map_overlay, "ТАКТИЧЕСКАЯ КАРТА · обнаруженные контакты", 34, 27, 1000, 40, 23, GOLD)
	button(map_overlay, "Закрыть", toggle_map, 1100, 25, 146)
	map_view = TacticalMap.new()
	map_view.world = world
	place(map_view, map_overlay, 34, 88, 910, 590)
	map_view.tapped.connect(func(point: Vector3, index: int) -> void:
		if index >= 0:
			world.map_selected = world.ships[index]
			if world.map_selected.team != world.player.team and not world.spectator.active:
				world.player.target = world.map_selected
		else:
			if not world.spectator.active:
				if world.player.set_waypoint(point, append_route or Input.is_physical_key_pressed(KEY_SHIFT)):
					world.log_event("Штурман: автопилот, точка %.0f / %.0f м" % [point.x, point.z])
				else:
					world.log_event("Точка вне карты или достигнут лимит 32 точек"))
	map_info = label(map_overlay, "Выберите судно.\n\nКасание воды: маршрут.\nПеретаскивание: карта.\nДва пальца: масштаб.\n\nВключите очередь, чтобы\nдобавить несколько точек.", 970, 100, 270, 245, 17)
	append_route_button = CheckButton.new()
	append_route_button.text = "Добавлять точки"
	place(append_route_button, map_overlay, 970, 354, 270, 48)
	append_route_button.toggled.connect(func(enabled: bool) -> void: append_route = enabled)
	button(map_overlay, "Взять управление", func() -> void:
		if world.spectator.take_control(world.map_selected):
			show_game(), 970, 420, 270)
	button(map_overlay, "Наблюдать за судном", func() -> void:
		if world.map_selected != null:
			world.camera_manager.follow = world.map_selected
			world.camera_manager.set_mode(0)
			map_overlay.hide()
			modal_visible = false, 970, 480, 270)
	button(map_overlay, "Очистить маршрут", func() -> void:
		world.player.waypoints.clear()
		world.player.autopilot = false, 970, 540, 270)
	button(map_overlay, "Остановить автопилот", func() -> void: world.player.autopilot = false, 970, 600, 270)
	map_overlay.hide()

func toggle_map() -> void:
	if map_overlay == null:
		return
	map_overlay.visible = not map_overlay.visible
	modal_visible = map_overlay.visible

func toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		close_modal()
		return
	get_tree().paused = true
	var box: Panel = new_modal("Пауза", 560, 390)
	button(box, "Продолжить", toggle_pause, 30, 90, 500)
	button(box, "Настройки", show_settings, 30, 152, 500)
	button(box, "Вернуться в меню", world.show_menu, 30, 214, 500)
	label(box, "В меню бой завершается. Сценарии сохраняются в редакторе.", 30, 300, 500, 55, 13, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func show_results(message: String) -> void:
	var box: Panel = new_modal("Итоги операции", 760, 420)
	label(box, message, 30, 82, 700, 65, 22, TEAL)
	label(box, "Время %02d:%02d · в строю: союзных %d / вражеских %d\nБаланс %d · репутация %d" % [int(world.elapsed) / 60, int(world.elapsed) % 60, world.alive_count(0), world.alive_count(1), world.economy.credits, world.economy.reputation], 30, 164, 700, 64, 17)
	button(box, "Повторить", func() -> void:
		if world.mission.active >= 0:
			world.start_mission(world.mission.active)
		else:
			world.start_battle(world.current_scenario, world.spectator.active), 30, 267, 220)
	button(box, "Сохранить сценарий", func() -> void:
		world.editor.scenario = world.current_scenario.duplicate(true)
		world.save_scenario(), 270, 267, 220)
	button(box, "Главное меню", world.show_menu, 510, 267, 220)
	label(box, "Окно можно закрыть, чтобы наблюдать дальнейшее затопление.", 30, 347, 700, 28, 14, MUTED)

func toggle_ui() -> void:
	hidden_ui = not hidden_ui
	screen.visible = not hidden_ui
	if hidden_ui:
		var reveal: Button = button(root, "HUD", func() -> void:
			hidden_ui = false
			screen.show()
			root.get_node("RevealHUD").queue_free(), 1180, 20, 80)
		reveal.name = "RevealHUD"

func show_editor() -> void:
	clear_screen()
	preview = false
	panel(screen, 14, 14, 1252, 76)
	label(screen, "РЕДАКТОР СРАЖЕНИЙ", 34, 24, 650, 35, 26, GOLD)
	label(screen, "Касание — добавить / выбрать. Перетаскивание — переместить. Два пальца — масштаб.", 34, 60, 1030, 24, 13, MUTED)
	button(screen, "Меню", world.show_menu, 1110, 28, 140)
	map_view = TacticalMap.new()
	map_view.world = world
	place(map_view, screen, 20, 104, 850, 532)
	map_view.tapped.connect(editor_tap)
	map_view.unit_moved.connect(func(index: int, point: Vector3) -> void:
		world.editor.selected = index
		if world.editor.move_selected(point):
			var spec: Dictionary = world.editor.scenario["units"][index]
			world.ships[index].position = Vector3(spec["x"], 0, spec["z"])
		elif toast != world.editor.last_error or toast_time <= 0:
			world.log_event(world.editor.last_error))
	var side: Panel = panel(screen, 888, 104, 372, 532)
	var map_choice: OptionButton = option(side, ["Архипелаг", "Открытый океан"], 14, 12, 344)
	map_choice.select(1 if world.editor.scenario.get("map") == "ocean" else 0)
	map_choice.item_selected.connect(func(index: int) -> void:
		world.editor.scenario["map"] = ["archipelago", "ocean"][index]
		world.refresh_preview())
	var types: OptionButton = option(side, VesselCatalog.NAMES, 14, 66, 344)
	types.select(VesselCatalog.IDS.find(world.editor.vessel_type))
	types.item_selected.connect(func(index: int) -> void: world.editor.vessel_type = VesselCatalog.IDS[index])
	var teams: OptionButton = option(side, ["Союзный флот", "Противник"], 14, 120, 166)
	teams.select(world.editor.team)
	teams.item_selected.connect(func(index: int) -> void:
		world.editor.team = index
		if world.editor.selected >= 0:
			world.editor.scenario["units"][world.editor.selected]["team"] = index
			world.refresh_preview())
	var tool: OptionButton = option(side, ["Выбрать", "Добавить"], 192, 120, 166)
	tool.select(0 if world.editor.tool == "select" else 1)
	tool.item_selected.connect(func(index: int) -> void: world.editor.tool = ["select", "add"][index])
	button(side, "Повернуть +45°", func() -> void:
		if not world.editor.rotate_selected(45):
			world.log_event(world.editor.last_error)
		world.refresh_preview(), 14, 178, 166)
	button(side, "Дублировать", func() -> void:
		if not world.editor.duplicate_selected():
			world.log_event(world.editor.last_error)
		world.refresh_preview(), 192, 178, 166)
	button(side, "Удалить", func() -> void:
		world.editor.delete_selected()
		world.refresh_preview(), 14, 236, 166)
	button(side, "Под управление", func() -> void:
		if world.editor.selected >= 0:
			world.editor.scenario["player_index"] = world.editor.selected, 192, 236, 166)
	var weather: OptionButton = option(side, ["Ясно", "Шторм"], 14, 296, 166)
	weather.select(1 if world.editor.scenario.get("weather") == "storm" else 0)
	weather.item_selected.connect(func(index: int) -> void:
		world.editor.scenario["weather"] = ["clear", "storm"][index]
		world.editor.scenario["waves"] = 1.0 if index == 0 else 2.8
		world.refresh_preview())
	var night: CheckButton = CheckButton.new()
	night.text = "Ночь"
	night.button_pressed = world.editor.scenario.get("night", false)
	place(night, side, 192, 296, 166, 44)
	night.toggled.connect(func(value: bool) -> void:
		world.editor.scenario["night"] = value
		world.refresh_preview())
	button(side, "Параметры боя", show_scenario_settings, 14, 352, 344)
	editor_info = label(side, "", 14, 412, 344, 105, 15, TEAL)
	button(screen, "Сохранить", world.save_scenario, 20, 654, 148)
	button(screen, "Загрузить", func() -> void:
		if world.load_scenario():
			show_editor(), 182, 654, 148)
	button(screen, "3D-просмотр", func() -> void:
		preview = not preview
		map_view.visible = not preview
		world.camera_manager.set_mode(0 if preview else 4), 344, 654, 156)
	button(screen, "Пример 3+2 / 4+2", func() -> void:
		world.editor.scenario = VesselCatalog.default_scenario()
		world.editor.selected = -1
		world.refresh_preview()
		show_editor(), 514, 654, 216)
	button(screen, "Наблюдать", func() -> void: world.start_battle(world.editor.scenario, true), 888, 654, 172)
	button(screen, "НАЧАТЬ БОЙ", func() -> void: world.start_battle(world.editor.scenario), 1074, 654, 186).add_theme_color_override("font_color", GOLD)

func editor_tap(point: Vector3, index: int) -> void:
	if world.editor.tool == "add":
		if world.editor.add_unit(point):
			world.refresh_preview()
		else:
			world.log_event(world.editor.last_error)
	else:
		world.editor.selected = index
		if index >= 0:
			world.camera_manager.follow = world.ships[index]

func spin(parent: Control, x: float, y: float, value: float, minimum: float, maximum: float, step: float = 1) -> SpinBox:
	var item: SpinBox = SpinBox.new()
	item.min_value = minimum
	item.max_value = maximum
	item.step = step
	item.value = value
	place(item, parent, x, y, 270, 44)
	return item

func show_scenario_settings() -> void:
	var box: Panel = new_modal("Параметры сценария", 900, 650)
	var data: Dictionary = world.editor.scenario.duplicate(true)
	var selected: int = world.editor.selected
	var fields: Array[String] = ["waves", "wind", "ammo_scale", "time_limit"]
	var captions: Array[String] = ["Амплитуда волн, м", "Направление ветра, рад", "Боезапас, множитель", "Лимит боя, с"]
	var defaults: Array[float] = [1, 0.7, 1, 900]
	for i: int in 4:
		var key: String = fields[i]
		label(box, captions[i], 30, 86 + i * 58, 490, 44)
		var item: SpinBox = spin(box, 580, 86 + i * 58, data.get(key, defaults[i]), 30 if i == 3 else 0, [6, 6.28, 4, 3600][i], 30 if i == 3 else 0.1)
		item.value_changed.connect(func(value: float) -> void: data[key] = value)
	label(box, "ИИ", 30, 328, 400, 40)
	var difficulty: OptionButton = option(box, ["Лёгкий", "Средний", "Сложный"], 580, 322, 270)
	difficulty.select(int(data.get("difficulty", 1)))
	difficulty.item_selected.connect(func(index: int) -> void: data["difficulty"] = index)
	label(box, "Условие завершения", 30, 384, 400, 40)
	var victory: OptionButton = option(box, ["Уничтожение флота", "Лимит времени"], 580, 378, 270)
	victory.select(1 if data.get("victory") == "time" else 0)
	victory.item_selected.connect(func(index: int) -> void: data["victory"] = ["elimination", "time"][index])
	if world.editor.selected >= 0:
		var spec: Dictionary = data["units"][world.editor.selected]
		label(box, "Выбранное судно · курс / скорость м/с", 30, 448, 500, 40)
		var heading: SpinBox = spin(box, 580, 438, spec.get("heading", 0), 0, 359)
		heading.value_changed.connect(func(value: float) -> void: spec["heading"] = value)
		var speed: SpinBox = spin(box, 580, 494, spec.get("speed", 0), -5, 21, 0.5)
		speed.value_changed.connect(func(value: float) -> void: spec["speed"] = value)
	var error_label: Label = label(box, "", 30, 616, 820, 28, 13, Color("ee876d"))
	button(box, "Применить", func() -> void:
		if not world.editor.load_scenario(data):
			error_label.text = world.editor.last_error
			return
		world.editor.selected = selected
		world.refresh_preview()
		close_modal(), 30, 568, 820)

func _process(delta: float) -> void:
	if root == null:
		return
	var available: Vector2 = get_viewport_rect().size
	var factor: float = minf(available.x / 1280, available.y / 720)
	root.scale = Vector2.ONE * factor
	root.position = (available - Vector2(1280, 720) * factor) * 0.5
	tick += delta
	toast_time = maxf(0, toast_time - delta)
	if tick < 0.15:
		return
	tick = 0
	if editor_info != null:
		var index: int = world.editor.selected
		var count: int = world.editor.scenario["units"].size()
		editor_info.text = "Судов: %d / 24\n" % count
		if index >= 0 and index < count:
			var spec: Dictionary = world.editor.scenario["units"][index]
			editor_info.text += "№%d · %.0f / %.0f м\nКурс %.0f° · ход %.1f м/с" % [index + 1, spec["x"], spec["z"], spec.get("heading", 0), spec.get("speed", 0)]
		else:
			editor_info.text += "Выберите объект на карте"
		if toast_time > 0:
			editor_info.text = toast
	if status_label == null or world.player == null:
		return
	var ship: ShipController = world.player
	if append_route_button != null:
		append_route_button.text = "Добавлять точки · %d/32" % ship.waypoints.size()
	status_label.text = "%s  ·  %03d°  ·  %.1f уз  ·  %d об/мин  ·  Руль %+d°" % [ship.unit_name, ship.heading_degrees(), absf(ship.speed) * 1.944, int(absf(ship.throttle) * 900), int(ship.rudder * 35)]
	var hp: float = ship.damage.health / ship.damage.maximum * 100
	depth_label.text = "%s · Корпус %.0f%% · Вода %.0f%% · Пожар %.0f%% · %s · ×%d" % [ship.stats["name"], hp, ship.damage.flooding * 100, ship.damage.fire * 100, "НАБЛЮДАТЕЛЬ" if world.spectator.active else ("АВТОПИЛОТ" if ship.autopilot else "РУЧНОЕ"), int(Engine.time_scale)]
	if ship is SubmarineController:
		var sub: SubmarineController = ship as SubmarineController
		depth_label.text = "Глубина %.1f → %.0f м · Балласт %+.0f%% · АКБ %.0f%% · Воздух %.0f%% · Шум %.0f · Корпус %.0f%%" % [ship.get_depth(), sub.target_depth, sub.ballast * 100, sub.battery, sub.air, sub.noise, hp]
	var target_name: String = ship.target.unit_name if is_instance_valid(ship.target) and not ship.target.damage.sinking and world.can_detect(ship.team, ship.target) else "свободный прицел"
	combat_label.text = "Цель: %s\nБоезапас %d · готовность %.1f с\nКамера: %s" % [target_name, ship.ammo[world.selected_weapon], ship.cooldowns[world.selected_weapon], CameraManager.MODES[world.camera_manager.mode]]
	mission_label.text = world.mission.status if world.mission.active >= 0 else ("" if toast_time <= 0 else toast)
	var start: int = maxi(0, world.journal.size() - 3)
	log_label.text = "\n".join(world.journal.slice(start))
	if map_info != null and world.map_selected != null:
		var selected: ShipController = world.map_selected
		map_info.text = "%s\n%s\n\nКурс %03d° · %.1f уз\nГлубина %.1f м\nКорпус %.0f%%\n\nX %.0f · Z %.0f м\n\nКасание воды: маршрут.\nДва пальца: масштаб." % [selected.unit_name, selected.stats["name"], selected.heading_degrees(), absf(selected.speed) * 1.944, selected.get_depth(), selected.damage.health / selected.damage.maximum * 100, selected.position.x, selected.position.z]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and get_tree().paused:
		toggle_pause()
		get_viewport().set_input_as_handled()
