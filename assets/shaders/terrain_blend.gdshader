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
uniform vec3 haze_color = vec3(0.86, 0.58, 0.36);
uniform float haze_start = 48.0;
uniform float haze_end = 240.0;

varying vec3 world_pos;
varying vec3 world_n;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Tangent frame from the geometric normal so CPU meshes can skip generate_tangents().
	vec3 up = abs(NORMAL.y) > 0.94 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	TANGENT = normalize(cross(up, NORMAL));
	BINORMAL = normalize(cross(NORMAL, TANGENT));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
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

vec2 rot2(vec2 v, float ang) {
	float c = cos(ang);
	float s = sin(ang);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Triangle-grid stochastic tiling: rotate/offset UVs per cell, barycentric blend.
vec4 sample_stoch(sampler2D tex, vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	vec2 v0 = i;
	vec2 v1 = i + vec2(1.0, 0.0);
	vec2 v2 = i + vec2(0.0, 1.0);
	vec3 w = vec3(1.0 - f.x - f.y, f.x, f.y);
	if (w.x < 0.0) {
		v0 = i + vec2(1.0, 1.0);
		w = vec3(f.x + f.y - 1.0, 1.0 - f.y, 1.0 - f.x);
	}
	vec2 h0 = hash22(v0);
	vec2 h1 = hash22(v1);
	vec2 h2 = hash22(v2);
	vec4 c0 = texture(tex, rot2(uv, h0.x * 6.2831853) * (0.72 + h0.y * 0.22) + h0 * 5.3);
	vec4 c1 = texture(tex, rot2(uv, h1.x * 6.2831853) * (0.72 + h1.y * 0.22) + h1 * 5.3);
	vec4 c2 = texture(tex, rot2(uv, h2.x * 6.2831853) * (0.72 + h2.y * 0.22) + h2 * 5.3);
	return c0 * w.x + c1 * w.y + c2 * w.z;
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

vec4 sample_tri_stoch(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 blending = abs(n);
	blending = pow(blending, vec3(4.0));
	blending = blending / (blending.x + blending.y + blending.z + 1e-5);
	vec4 xaxis = sample_stoch(tex, p.yz * scale);
	vec4 yaxis = sample_stoch(tex, p.xz * scale);
	vec4 zaxis = sample_stoch(tex, p.xy * scale);
	return xaxis * blending.x + yaxis * blending.y + zaxis * blending.z;
}

vec3 sample_sand(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 detail = sample_tri_stoch(tex, p, n, scale).rgb;
	vec3 meso = sample_tri_stoch(tex, p + vec3(7.0, 0.0, 3.0), n, scale * 0.31).rgb;
	vec3 macro = sample_tri(tex, p + vec3(19.0, 0.0, 11.0), n, scale * 0.11).rgb;
	float w_meso = 0.38 + 0.18 * fbm(p.xz * 0.011);
	float w_macro = 0.28 + 0.16 * fbm(p.xz * 0.0048 + 5.0);
	return mix(mix(detail, meso, w_meso), macro, w_macro);
}

void fragment() {
	float slope = 1.0 - clamp(world_n.y, 0.0, 1.0);
	float rock_w = smoothstep(0.10, rock_slope, slope);
	float height_rock = smoothstep(6.0, 16.0, world_pos.y);
	rock_w = clamp(rock_w + height_rock * 0.55, 0.0, 1.0);

	float radial = length(world_pos.xz);
	float path = fbm(world_pos.xz * 0.045 + vec2(8.0, 3.0));
	float wash = smoothstep(0.48, 0.78, path);
	float core_pad = 1.0 - smoothstep(6.0, 16.0, radial);
	float packed = wash * 0.42 * (1.0 - rock_w) * (1.0 - core_pad * 0.85);
	float dirt_w = clamp(packed, 0.0, 1.0);
	float sand_w = clamp(1.0 - rock_w - dirt_w, 0.0, 1.0);

	vec3 sand = sample_sand(sand_albedo, world_pos, world_n, uv_scale) * sand_tint;
	vec3 dirt = sample_sand(dirt_albedo, world_pos, world_n, uv_scale * 0.72) * dirt_tint;
	vec3 rock = sample_tri(rock_albedo, world_pos, world_n, uv_scale * 0.48).rgb * rock_tint;

	float blotch = smoothstep(0.28, 0.78, fbm(world_pos.xz * 0.021 + 12.0));
	float dune = fbm(world_pos.xz * 0.0062 + 3.4);
	sand *= mix(vec3(1.12, 0.97, 0.78), vec3(0.82, 0.54, 0.30), blotch * 0.42 + dune * 0.28);
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

	float dist = length(world_pos.xz);
	float haze = smoothstep(haze_start, haze_end, dist);
	albedo = mix(albedo, haze_color, haze * 0.58);
	ALBEDO = albedo;

	float rs = sample_tri_stoch(sand_rough, world_pos, world_n, uv_scale).r;
	float rd = sample_tri(dirt_rough, world_pos, world_n, uv_scale * 0.92).r;
	float rr = sample_tri(rock_rough, world_pos, world_n, uv_scale * 0.48).r;
	ROUGHNESS = clamp(rs * sand_w + rd * dirt_w + rr * rock_w, 0.32, 1.0);
	ROUGHNESS = mix(ROUGHNESS, 0.96, haze * 0.45);
	METALLIC = 0.01 * (1.0 - rock_w);
	SPECULAR = mix(0.18, 0.04, haze);

	vec3 ns = sample_tri_stoch(sand_normal, world_pos, world_n, uv_scale).rgb;
	vec3 ns_fine = sample_tri_stoch(sand_normal, world_pos, world_n, uv_scale * 3.6).rgb;
	float rip_x = sin(world_pos.x * 5.4 + world_pos.z * 1.15);
	float rip_z = sin(world_pos.z * 4.8 - world_pos.x * 0.95);
	vec3 nproc = vec3(rip_x * 0.5 + 0.5, rip_z * 0.5 + 0.5, 1.0);
	ns = mix(mix(ns, ns_fine, 0.40), nproc, 0.16 * sand_w);
	vec3 nd = sample_tri(dirt_normal, world_pos, world_n, uv_scale * 0.92).rgb;
	vec3 nr = sample_tri(rock_normal, world_pos, world_n, uv_scale * 0.48).rgb;
	vec3 nr_band = sample_tri(rock_normal, world_pos, world_n, uv_scale * 0.18).rgb;
	nr = mix(nr, nr_band, strata * 0.42);
	NORMAL_MAP = ns * sand_w + nd * dirt_w + nr * rock_w;
	NORMAL_MAP_DEPTH = mix(1.15, 0.12, haze);
}
