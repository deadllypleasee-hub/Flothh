class_name CrewSystem
extends RefCounted
signal report(message: String)
const ROLES: Array[String] = ["Капитан", "Штурман", "Механик", "Радар", "Сонар", "Офицер вооружения", "Ремонтная команда"]
var task: String = "repair"
var morale: float = 1.0
var efficiency: float = 1.0

func order(new_task: String) -> void:
	if new_task not in ["repair", "fire", "pump"]:
		return
	task = new_task
	var names: Dictionary = {"repair": "Ремонт механизмов", "fire": "Тушение пожара", "pump": "Откачка воды"}
	report.emit("Механик: %s" % names[task])

func tick(delta: float, damage: DamageSystem) -> void:
	morale = move_toward(morale, clampf(damage.health / damage.maximum + 0.25, 0.3, 1), delta * 0.02)
	efficiency = (0.5 + morale * 0.5) * maxf(0.4, damage.power)
	damage.tick(delta, task, efficiency)
