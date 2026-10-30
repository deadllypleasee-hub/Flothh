shader_type spatial;
render_mode cull_disabled;
uniform float clock = 0.0;
uniform float amplitude = 1.0;
uniform vec2 direction = vec2(0.8, 0.6);
uniform vec3 deep_color : source_color = vec3(0.016, 0.10, 0.15);
varying vec3 world_pos;
float wave(vec2 p) {
	return amplitude * (sin(dot(p, direction) * 0.045 + clock * 0.9) * 0.65 + sin(dot(p, vec2(-0.6, 0.8)) * 0.083 + clock * 1.37) * 0.35);
}
void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += wave(p.xz);
	float dx = (wave(p.xz + vec2(0.7, 0.0)) - wave(p.xz - vec2(0.7, 0.0))) / 1.4;
	float dz = (wave(p.xz + vec2(0.0, 0.7)) - wave(p.xz - vec2(0.0, 0.7))) / 1.4;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
	world_pos = p;
}
void fragment() {
	float ripples = sin(world_pos.x * 0.8 + clock * 2.0) * sin(world_pos.z * 0.65 - clock);
	float foam = smoothstep(0.74, 1.0, sin(dot(world_pos.xz, direction) * 0.045 + clock * 0.9)) * clamp(amplitude / 6.0, 0.0, 0.5);
	ALBEDO = mix(deep_color + vec3(ripples * 0.012), vec3(0.47, 0.67, 0.68), foam);
	METALLIC = 0.35;
	ROUGHNESS = 0.22 + foam * 0.4;
	SPECULAR = 0.85;
}
