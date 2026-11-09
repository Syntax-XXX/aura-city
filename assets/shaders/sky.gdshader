shader_type sky;
// Tag/Nacht-Himmel: Verlauf, Abendrot zur Sonne, Sonnenscheibe, Wolken, Sterne.
// Bewusst ohne TIME (Wolken-Versatz kommt als Uniform) – billig zu rendern.
uniform vec3 sky_top : source_color = vec3(0.2, 0.45, 0.85);
uniform vec3 sky_horizon : source_color = vec3(0.7, 0.82, 0.95);
uniform vec3 ground_color : source_color = vec3(0.25, 0.28, 0.3);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float sunset : hint_range(0.0, 1.0) = 0.0;
uniform vec2 cloud_offset = vec2(0.0);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col = mix(sky_horizon, sky_top, clamp(pow(max(h, 0.0), 0.55), 0.0, 1.0));
	float sd = LIGHT0_ENABLED ? max(dot(dir, LIGHT0_DIRECTION), 0.0) : 0.0;
	// Glühen rund um die Sonne, abends stärker und orange
	col += sun_color * pow(sd, 6.0) * (0.12 + sunset * 0.55) * (1.0 - night);
	col += sun_color * smoothstep(0.9990, 0.9996, sd) * 6.0 * (1.0 - night);
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.12) * 0.9 + cloud_offset;
		float n = fbm(uv * 1.3);
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.3, n) * smoothstep(0.0, 0.2, h);
		vec3 cloud = mix(vec3(1.0), sun_color * vec3(1.0, 0.75, 0.6), sunset * 0.7) * mix(1.0, 0.12, night);
		col = mix(col, cloud, c * 0.85);
		// Sterne
		vec2 sp = floor(dir.xz / (h + 1.0) * 500.0);
		float star = step(0.9975, hash(sp)) * (0.6 + 0.4 * hash(sp + 3.1));
		col += vec3(star) * night * smoothstep(0.02, 0.25, h) * (1.0 - c);
	} else {
		col = mix(sky_horizon, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}
	COLOR = col;
}
