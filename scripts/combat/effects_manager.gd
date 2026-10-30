class_name EffectsManager
extends Node3D
## Bounded concurrent effects. GPU particles, emissive flashes and positional synthesis.
var max_effects: int = 20
var particle_scale: float = 1.0
var effects: Array[Dictionary] = []
var sound_cache: Dictionary = {}
var audio_enabled: bool = true
var random: RandomNumberGenerator = RandomNumberGenerator.new()
var soft_texture: ImageTexture
var engine_audio: AudioStreamPlayer3D
var sea_audio: AudioStreamPlayer
var listener_ship: ShipController
var headless: bool = false

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	var command_line: PackedStringArray = OS.get_cmdline_args()
	var driver_index: int = command_line.find("--audio-driver")
	if driver_index >= 0 and driver_index + 1 < command_line.size() and command_line[driver_index + 1] == "Dummy":
		headless = true
	random.seed = 124987
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			var r: float = Vector2(x - 15.5, y - 15.5).length() / 16
			image.set_pixel(x, y, Color(1, 1, 1, clampf(1 - r * r, 0, 1) * 0.65))
	soft_texture = ImageTexture.create_from_image(image)
	sea_audio = AudioStreamPlayer.new()
	sea_audio.stream = make_loop("sea")
	sea_audio.volume_db = -27
	add_child(sea_audio)
	if not headless:
		sea_audio.play()
	engine_audio = AudioStreamPlayer3D.new()
	engine_audio.stream = make_loop("engine")
	engine_audio.unit_size = 80
	engine_audio.max_distance = 1500
	engine_audio.volume_db = -30
	add_child(engine_audio)
	if not headless:
		engine_audio.play()

func _process(delta: float) -> void:
	sea_audio.volume_db = -25 if audio_enabled else -80
	if is_instance_valid(listener_ship) and listener_ship.is_inside_tree():
		engine_audio.global_position = listener_ship.global_position
		engine_audio.pitch_scale = 0.65 + absf(listener_ship.throttle) * 0.8
		engine_audio.volume_db = -28 + absf(listener_ship.throttle) * 10 if audio_enabled else -80
	for i: int in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[i]
		effect["remaining"] = float(effect["remaining"]) - delta
		var root: Node3D = effect["node"]
		if effect["flash"] != null:
			var flash: MeshInstance3D = effect["flash"]
			flash.scale += Vector3.ONE * delta * 12
			flash.visible = float(effect["remaining"]) > float(effect["life"]) - 0.22
		if effect.get("ring") != null:
			var ring: MeshInstance3D = effect["ring"]
			ring.scale += Vector3.ONE * delta * 9
		if float(effect["remaining"]) <= 0:
			root.queue_free()
			effects.remove_at(i)

func spawn_effect(kind: String, point: Vector3) -> void:
	if effects.size() >= max_effects:
		return
	var root: Node3D = Node3D.new()
	add_child(root)
	root.global_position = point
	var life: float = 1.8 if kind in ["explosion", "splash", "underwater"] else 2.8
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = maxi(4, int((32 if kind == "explosion" else 18) * particle_scale))
	particles.lifetime = life * 0.8
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 170 if kind == "explosion" else 30
	process.initial_velocity_min = 4 if kind in ["wake", "smoke"] else 12
	process.initial_velocity_max = 12 if kind in ["wake", "smoke"] else 35
	process.gravity = Vector3(0, 2 if kind == "smoke" else -8, 0)
	process.scale_min = 1.0
	process.scale_max = 3.5 if kind == "smoke" else 2.0
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	var colors: Dictionary = {"explosion": Color("ffae52"), "fire": Color("ff813d"), "splash": Color("c2e9e9"), "underwater": Color("7bf4eb"), "wake": Color("b3d1d0"), "smoke": Color("33383c"), "muzzle": Color("ffe6a2"), "trail": Color("c0c1bd"), "bubble": Color("a5e2df")}
	var mat: StandardMaterial3D = ShipModel.material(colors.get(kind, Color.WHITE), 0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if kind in ["explosion", "muzzle", "fire"]:
		mat.emission_enabled = true
		mat.emission = Color("ff7b31")
		mat.emission_energy_multiplier = 2
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.7 if kind in ["trail", "bubble"] else 1.5
	mesh.height = mesh.radius * 2
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = mat
	if kind in ["smoke", "trail", "splash", "fire"]:
		var puff: QuadMesh = QuadMesh.new()
		puff.size = Vector2(9, 9) if kind == "smoke" else Vector2(2, 4)
		mat.albedo_texture = soft_texture
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		puff.material = mat
		particles.draw_pass_1 = puff
	elif kind == "wake":
		var foam: PlaneMesh = PlaneMesh.new()
		foam.size = Vector2(7, 12)
		mat.albedo_texture = soft_texture
		foam.material = mat
		particles.draw_pass_1 = foam
		process.initial_velocity_min = 0.5
		process.initial_velocity_max = 1.2
		process.gravity = Vector3.ZERO
		root.position.y += 0.8
	else:
		particles.draw_pass_1 = mesh
	particles.process_material = process
	root.add_child(particles)
	var flash: MeshInstance3D = null
	var ring: MeshInstance3D = null
	if kind in ["explosion", "muzzle", "underwater"]:
		flash = MeshInstance3D.new()
		flash.mesh = mesh
		flash.scale = Vector3.ONE * 2
		root.add_child(flash)
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color("ffae60")
		light.light_energy = 3
		light.omni_range = 70
		root.add_child(light)
		var tween: Tween = create_tween()
		tween.tween_property(light, "light_energy", 0.0, 0.35)
		play_sound("explosion" if kind != "muzzle" else "gun", point)
		if kind != "muzzle":
			ring = MeshInstance3D.new()
			var torus: TorusMesh = TorusMesh.new()
			torus.inner_radius = 1.8
			torus.outer_radius = 2.1
			torus.rings = 16
			torus.ring_segments = 6
			ring.mesh = torus
			ring.material_override = mat
			root.add_child(ring)
	effects.append({"node": root, "remaining": life, "life": life, "flash": flash, "ring": ring})

func make_loop(kind: String) -> AudioStreamWAV:
	var sample_rate: int = 16000
	var samples: int = sample_rate * 2
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	var low_pass: float = 0
	for i: int in samples:
		var t: float = float(i) / sample_rate
		low_pass = low_pass * 0.94 + random.randf_range(-0.5, 0.5) * 0.06
		var value: float = low_pass * (0.7 + sin(t * PI) * 0.25) if kind == "sea" else sin(t * TAU * 55) * 0.2 + sin(t * TAU * 110) * 0.1
		# Fade seam for the non-periodic sea loop.
		if kind == "sea":
			value *= minf(1, minf(t * 8, (2 - t) * 8))
		data.encode_s16(i * 2, int(value * 26000))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples
	return stream

func make_sound(kind: String) -> AudioStreamWAV:
	var sample_rate: int = 16000
	var duration: float = 1.2 if kind == "explosion" else 0.5
	var samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	for i: int in samples:
		var t: float = float(i) / sample_rate
		var envelope: float = exp(-t * (4 if kind == "explosion" else 9))
		var frequency: float = 900 if kind == "sonar" else 65
		var value: float = sin(t * TAU * frequency) * 0.35
		if kind != "sonar":
			value += random.randf_range(-0.6, 0.6)
		data.encode_s16(i * 2, int(clampf(value * envelope, -1, 1) * 26000))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

func play_sound(kind: String, point: Vector3) -> void:
	if headless or not audio_enabled or get_child_count() > max_effects + 16:
		return
	if not sound_cache.has(kind):
		sound_cache[kind] = make_sound(kind)
	var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio.stream = sound_cache[kind]
	audio.max_distance = 3500
	audio.unit_size = 100
	audio.volume_db = -10
	add_child(audio)
	audio.global_position = point
	audio.finished.connect(audio.queue_free)
	audio.play()
