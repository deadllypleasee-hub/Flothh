class_name VesselCatalog
extends RefCounted
## Entirely fictional, deliberately compressed game characteristics. SI world units.

const IDS: Array[String] = ["patrol", "corvette", "frigate", "destroyer", "cruiser", "carrier", "diesel", "nuclear", "attack"]
const NAMES: Array[String] = ["Патрульный катер", "Корвет", "Фрегат", "Эсминец", "Ракетный крейсер", "Авианосец", "Дизельная подлодка", "Атомная подлодка", "Ударная подлодка"]

static func get_stats(id: String) -> Dictionary:
	var index: int = IDS.find(id)
	if index < 0:
		index = 3
	var lengths: Array[float] = [32, 64, 86, 112, 146, 215, 62, 110, 85]
	var beams: Array[float] = [7, 10, 12, 14, 19, 37, 7, 11, 9]
	var masses: Array[float] = [190, 850, 2100, 4800, 9200, 32000, 1500, 7100, 3900]
	var speeds: Array[float] = [21, 17, 16, 18, 16, 13, 11, 15, 16]
	var healths: Array[float] = [130, 270, 400, 580, 820, 1400, 330, 600, 460]
	var sub: bool = index >= 6
	return {"id": IDS[index], "name": NAMES[index], "length": lengths[index], "beam": beams[index],
		"mass": masses[index], "speed": speeds[index], "acceleration": 1.6 if index == 0 else 0.7,
		"turn": 0.22 if index == 0 else 0.09, "health": healths[index], "submarine": sub,
		"sensor": 1650.0 if sub else 2400.0, "power": 30.0 + index * 12.0,
		"maintenance": 120 + index * 180, "price": 4000 + index * 6000,
		"ammo": {"gun": 0 if sub else (60 if index == 5 else 160), "missile": 4 if sub else 12, "torpedo": 16 if sub else 8}}

static func spec(id: String, team: int, x: float, z: float, heading: float = 0.0) -> Dictionary:
	return {"type": id, "team": team, "x": x, "z": z, "heading": heading, "speed": 0.0}

static func default_scenario() -> Dictionary:
	var units: Array = []
	for i: int in 3:
		units.append(spec("destroyer", 0, -450.0 + i * 200.0, 650.0, 0))
	for i: int in 2:
		units.append(spec("diesel", 0, -650.0 + i * 700.0, 900.0, 0))
	for i: int in 4:
		units.append(spec("frigate" if i % 2 == 0 else "destroyer", 1, -500.0 + i * 260.0, -800.0, 180))
	for i: int in 2:
		units.append(spec("attack", 1, -650.0 + i * 1100.0, -1100.0, 180))
	return {"version": 1, "name": "Глубокие воды", "map": "archipelago", "weather": "storm",
		"night": true, "wind": 0.7, "waves": 2.8, "difficulty": 1, "victory": "elimination",
		"time_limit": 900.0, "ammo_scale": 1.0, "player_index": 0, "units": units}
