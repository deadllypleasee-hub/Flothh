class_name EconomyManager
extends RefCounted

var credits: int = 25000
var reputation: int = 0
var unlocked: Array[String] = ["patrol", "destroyer", "diesel"]
var upgrades: Dictionary = {"engine": 0, "sensors": 0, "defense": 0}
var completed: Array[int] = []
var saver: SaveManager = SaveManager.new()
var settings: Dictionary = {"quality": 1, "sound": true, "sensitivity": 1.0}

func load_progress() -> void:
	var data: Dictionary = saver.read_file("progress.json")
	if data.is_empty():
		return
	credits = maxi(0, int(data.get("credits", 25000)))
	reputation = maxi(0, int(data.get("reputation", 0)))
	for item: Variant in data.get("unlocked", []):
		if item is String and item in VesselCatalog.IDS and item not in unlocked:
			unlocked.append(item)
	for item: Variant in data.get("completed", []):
		if (item is int or item is float) and int(item) in range(10) and int(item) not in completed:
			completed.append(int(item))
	var saved_upgrades: Variant = data.get("upgrades", {})
	if saved_upgrades is Dictionary:
		for key: String in upgrades:
			upgrades[key] = clampi(int(saved_upgrades.get(key, 0)), 0, 3)
	var saved_settings: Variant = data.get("settings", {})
	if saved_settings is Dictionary:
		settings.merge(saved_settings, true)

func save() -> bool:
	return saver.write_file("progress.json", {"credits": credits, "reputation": reputation, "unlocked": unlocked,
		"completed": completed, "upgrades": upgrades, "settings": settings})

func reward(mission: int, amount: int) -> void:
	if mission in completed:
		return
	completed.append(mission)
	credits += amount
	reputation += 10
	save()

func unlock(id: String) -> bool:
	if id not in VesselCatalog.IDS or id in unlocked:
		return false
	var cost: int = VesselCatalog.get_stats(id)["price"]
	if credits < cost:
		return false
	credits -= cost
	unlocked.append(id)
	save()
	return true

func upgrade(kind: String) -> bool:
	if not upgrades.has(kind) or int(upgrades[kind]) >= 3:
		return false
	var cost: int = 3500 * (int(upgrades[kind]) + 1)
	if credits < cost:
		return false
	credits -= cost
	upgrades[kind] = int(upgrades[kind]) + 1
	save()
	return true

func service(ship: ShipController) -> bool:
	var cost: int = int(ship.stats["maintenance"]) + int(ship.damage.maximum - ship.damage.health) * 8
	if credits < cost:
		return false
	credits -= cost
	ship.damage.configure(ship.damage.maximum)
	ship.damage.fire = 0
	ship.damage.flooding = 0
	ship.damage.engine = 1
	ship.damage.steering = 1
	ship.damage.radar = 1
	ship.damage.weapons = 1
	ship.damage.power = 1
	ship.ammo = ship.stats["ammo"].duplicate()
	save()
	return true
