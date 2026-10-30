class_name WeatherSystem
extends Node3D

var ocean: OceanSystem
var environment: WorldEnvironment
var sun: DirectionalLight3D
var time_of_day: float = 11.0
var weather: String = "clear"
var auto_cycle: bool = true
var rain: GPUParticles3D
var camera: Camera3D

func _ready() -> void:
	environment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("284b6e")
	sky_material.sky_horizon_color = Color("92b3be")
	sky_material.ground_bottom_color = Color("0c2736")
	sky_material.ground_horizon_color = Color("92b3be")
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6e98b5")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("6b8d9c")
	env.fog_density = 0.00018
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -35, 0)
	sun.light_color = Color("ffdba6")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500
	add_child(sun)
	rain = GPUParticles3D.new()
	rain.amount = 320
	rain.lifetime = 1.8
	rain.visibility_aabb = AABB(Vector3(-70, -80, -70), Vector3(140, 160, 140))
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(55, 0, 55)
	process.direction = Vector3(-0.2, -1, 0)
	process.spread = 5
	process.initial_velocity_min = 55
	process.initial_velocity_max = 70
	process.gravity = Vector3(0, -3, 0)
	rain.process_material = process
	var drop: BoxMesh = BoxMesh.new()
	drop.size = Vector3(0.035, 1.2, 0.035)
	var mat: StandardMaterial3D = ShipModel.material(Color(0.55, 0.72, 0.8, 0.35), 0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = mat
	rain.draw_pass_1 = drop
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)
	apply("clear", false)

func apply(kind: String, night: bool, waves: float = -1.0, wind: float = 0.5) -> void:
	weather = kind
	time_of_day = 23.0 if night else 11.0
	if ocean != null:
		ocean.amplitude = waves if waves >= 0 else (3.2 if kind == "storm" else 1.0)
		ocean.wind_direction = Vector2(cos(wind), sin(wind))
	rain.emitting = kind == "storm"
	_update_light()

func _process(delta: float) -> void:
	if auto_cycle:
		time_of_day = fposmod(time_of_day + delta / 180.0, 24)
	_update_light()
	if camera != null:
		rain.global_position = camera.global_position + Vector3(0, 50, 0)
		var submerged: bool = camera.global_position.y < -1
		environment.environment.fog_density = 0.018 if submerged else (0.00065 if weather == "storm" else 0.00018)
		var night: bool = time_of_day < 6 or time_of_day > 19
		environment.environment.fog_light_color = Color("103b48") if submerged else (Color("1c3044") if night else Color("637f96"))

func _update_light() -> void:
	var daylight: float = clampf(sin((time_of_day - 6) / 24 * TAU), 0, 1)
	sun.rotation_degrees.x = -20 - daylight * 50
	sun.light_energy = (0.35 + daylight * 1.15) * (0.65 if weather == "storm" else 1.0)
	environment.environment.ambient_light_energy = 0.38 + daylight * 0.45
	var sky: ProceduralSkyMaterial = environment.environment.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color("071124").lerp(Color("284b6e"), daylight)
	sky.sky_horizon_color = Color("243a50").lerp(Color("92b3be"), daylight)
	sky.ground_horizon_color = sky.sky_horizon_color
	sky.ground_bottom_color = Color("050f19").lerp(Color("0c2736"), daylight)
