shader_type spatial;
// Günstiges Wasser: Wellen nur über Normalen (kein Vertex-Displacement), Fresnel, Glitzern.
render_mode specular_schlick_ggx;
uniform vec3 deep : source_color = vec3(0.02, 0.18, 0.28);
uniform vec3 shallow : source_color = vec3(0.05, 0.45, 0.55);
uniform float wave_scale = 0.08;
uniform float speed = 0.6;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), u.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), u.x), u.y);
}
float waves(vec2 p) {
	return n2(p * wave_scale + vec2(TIME * 0.05, TIME * 0.03) * speed) * 0.6
		+ n2(p * wave_scale * 2.7 - vec2(TIME * 0.07, -TIME * 0.04) * speed) * 0.4;
}
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_pos.xz;
	float e = 0.6;
	float c = waves(p);
	vec3 n = normalize(vec3(c - waves(p + vec2(e, 0.0)), 0.25, c - waves(p + vec2(0.0, e))));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep, shallow, c * 0.6 + fres * 0.4);
	ROUGHNESS = 0.06;
	METALLIC = 0.25;
	SPECULAR = 0.8;
}
