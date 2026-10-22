shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D sand_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float uv_scale : hint_range(0.02, 1.0) = 0.085;
uniform float rock_slope : hint_range(0.1, 1.0) = 0.38;
uniform vec3 sand_tint = vec3(1.1, 0.88, 0.62);
uniform vec3 dirt_tint = vec3(0.98, 0.68, 0.38);
uniform vec3 rock_tint = vec3(0.9, 0.72, 0.52);

varying vec3 world_pos;
varying vec3 world_n;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.07 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}

vec4 sample_tri(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 blending = abs(n);
	blending = pow(blending, vec3(4.0));
	blending = blending / (blending.x + blending.y + blending.z + 1e-5);
	vec4 xaxis = texture(tex, p.yz * scale);
	vec4 yaxis = texture(tex, p.xz * scale);
	vec4 zaxis = texture(tex, p.xy * scale);
	return xaxis * blending.x + yaxis * blending.y + zaxis * blending.z;
}

vec3 sample_dual(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 detail = sample_tri(tex, p, n, scale).rgb;
	vec3 macro = sample_tri(tex, p, n, scale * 0.17).rgb;
	float w = 0.38 + 0.28 * fbm(p.xz * 0.011);
	return mix(detail, macro, w);
}

void fragment() {
	float slope = 1.0 - clamp(world_n.y, 0.0, 1.0);
	float rock_w = smoothstep(0.10, rock_slope, slope);
	float height_rock = smoothstep(6.0, 16.0, world_pos.y);
	rock_w = clamp(rock_w + height_rock * 0.55, 0.0, 1.0);

	float radial = length(world_pos.xz);
	float macro = fbm(world_pos.xz * 0.016);
	float path = fbm(world_pos.xz * 0.045 + vec2(8.0, 3.0));
	float wash = smoothstep(0.48, 0.78, path);
	float core_pad = 1.0 - smoothstep(6.0, 16.0, radial);
	// Packed earth is the same sand family, just darker/warmer — no cool mud.
	float packed = wash * 0.42 * (1.0 - rock_w) * (1.0 - core_pad * 0.85);
	float sand_w = clamp(1.0 - rock_w - packed, 0.0, 1.0);
	float dirt_w = clamp(packed, 0.0, 1.0);
	sand_w = clamp(1.0 - rock_w - dirt_w, 0.0, 1.0);

	vec3 sand = sample_dual(sand_albedo, world_pos, world_n, uv_scale) * sand_tint;
	vec3 dirt = sample_dual(dirt_albedo, world_pos, world_n, uv_scale * 0.72) * dirt_tint;
	vec3 rock = sample_dual(rock_albedo, world_pos, world_n, uv_scale * 0.48) * rock_tint;

	float blotch = smoothstep(0.32, 0.72, fbm(world_pos.xz * 0.028 + 12.0));
	sand *= mix(vec3(1.1, 0.96, 0.78), vec3(0.86, 0.58, 0.32), blotch * 0.48);
	dirt *= mix(vec3(1.08, 0.86, 0.55), vec3(0.78, 0.5, 0.26), blotch * 0.35);

	float specks = step(0.93, vnoise(world_pos.xz * 0.42));
	float crust = step(0.88, vnoise(world_pos.xz * 0.09 + 4.0));
	vec3 albedo = sand * sand_w + dirt * dirt_w + rock * rock_w;
	albedo = mix(albedo, rock * 0.82, specks * 0.45 * (1.0 - rock_w));
	albedo = mix(albedo, sand * vec3(1.08, 0.96, 0.8), crust * 0.22 * (1.0 - rock_w));

	float band = fract(world_pos.y * 0.31 + fbm(world_pos.xz * 0.02) * 0.12);
	float strata = smoothstep(0.0, 0.07, band) * (1.0 - smoothstep(0.16, 0.28, band));
	albedo = mix(albedo, rock * vec3(1.14, 0.88, 0.64), strata * rock_w * 0.42);
	albedo = mix(albedo, rock * vec3(0.72, 0.5, 0.34), strata * rock_w * 0.18 * step(0.5, band));

	ALBEDO = albedo;

	float rs = sample_tri(sand_rough, world_pos, world_n, uv_scale).r;
	float rd = sample_tri(dirt_rough, world_pos, world_n, uv_scale * 0.92).r;
	float rr = sample_tri(rock_rough, world_pos, world_n, uv_scale * 0.48).r;
	ROUGHNESS = clamp(rs * sand_w + rd * dirt_w + rr * rock_w, 0.28, 1.0);
	METALLIC = 0.015 * (1.0 - rock_w);

	vec3 ns = sample_tri(sand_normal, world_pos, world_n, uv_scale).rgb;
	vec3 ns_fine = sample_tri(sand_normal, world_pos, world_n, uv_scale * 3.6).rgb;
	vec3 ns_rip = sample_tri(sand_normal, world_pos, world_n, uv_scale * 8.2).rgb;
	ns = mix(mix(ns, ns_fine, 0.42), ns_rip, 0.22);
	vec3 nd = sample_tri(dirt_normal, world_pos, world_n, uv_scale * 0.92).rgb;
	vec3 nr = sample_tri(rock_normal, world_pos, world_n, uv_scale * 0.48).rgb;
	vec3 nr_band = sample_tri(rock_normal, world_pos, world_n, uv_scale * 0.18).rgb;
	nr = mix(nr, nr_band, strata * 0.35);
	NORMAL_MAP = ns * sand_w + nd * dirt_w + nr * rock_w;
	NORMAL_MAP_DEPTH = 1.15;
}
