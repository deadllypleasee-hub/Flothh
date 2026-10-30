class_name DamageSystem
extends RefCounted

signal hit(amount: float)
signal sunk
var maximum: float = 580.0
var health: float = 580.0
var flooding: float = 0.0
var fire: float = 0.0
var engine: float = 1.0
var steering: float = 1.0
var radar: float = 1.0
var weapons: float = 1.0
var power: float = 1.0
var sinking: bool = false
var compartments: Array[float] = [0.0, 0.0, 0.0]

func configure(hp: float) -> void:
	maximum = hp
	health = hp

func apply_hit(amount: float, compartment: int = 1) -> void:
	if sinking or amount <= 0:
		return
	health = maxf(0, health - amount)
	compartments[clampi(compartment, 0, 2)] = minf(1, compartments[clampi(compartment, 0, 2)] + amount / maximum)
	flooding = clampf(flooding + amount / maximum * 0.32, 0, 1)
	fire = clampf(fire + amount / maximum * 0.23, 0, 1)
	var ratio: float = health / maximum
	engine = maxf(0.15, ratio)
	steering = maxf(0.2, ratio)
	radar = maxf(0.1, ratio)
	weapons = 0.0 if ratio < 0.12 else maxf(0.25, ratio)
	power = maxf(0.05, ratio)
	hit.emit(amount)
	check_sinking()

func tick(delta: float, task: String, efficiency: float) -> void:
	if sinking:
		return
	if task == "fire":
		fire = maxf(0, fire - delta * 0.035 * efficiency)
	elif task == "pump":
		flooding = maxf(0, flooding - delta * 0.025 * efficiency)
	elif task == "repair":
		health = minf(maximum, health + delta * 0.65 * efficiency)
		engine = minf(1, engine + delta * 0.006 * efficiency)
		steering = minf(1, steering + delta * 0.006 * efficiency)
		radar = minf(1, radar + delta * 0.004 * efficiency)
		weapons = minf(1, weapons + delta * 0.004 * efficiency)
		power = minf(1, power + delta * 0.004 * efficiency)
	flooding = minf(1, flooding + (0.001 if flooding > 0.45 else 0.0) * delta)
	health = maxf(0, health - (fire * 1.2 + flooding * 0.6) * delta)
	check_sinking()

func check_sinking() -> void:
	if not sinking and (health <= 0 or flooding >= 1):
		sinking = true
		sunk.emit()
