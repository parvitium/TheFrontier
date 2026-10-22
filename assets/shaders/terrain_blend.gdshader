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

vec2 sand_domain(vec3 p) {
	float ang = (fbm(p.xz * 0.0064) - 0.5) * 3.4;
	vec2 q = rot2(p.xz, ang);
	q += vec2(fbm(p.xz * 0.012 + 2.0), fbm(p.xz * 0.012 + 19.0)) * 11.0;
	return q;
}

vec3 sample_sand(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec2 d = sand_domain(p);
	vec3 warped = vec3(d.x, p.y, d.y);
	float s_jit = mix(0.78, 1.28, fbm(p.xz * 0.0036 + 8.0));
	vec3 detail = sample_tri_stoch(tex, warped, n, scale * s_jit).rgb;
	vec3 meso = sample_tri_stoch(tex, p + vec3(7.0, 0.0, 3.0), n, scale * 0.27).rgb;
	vec3 macro = sample_tri(tex, p + vec3(19.0, 0.0, 11.0), n, scale * 0.08).rgb;
	vec3 patch_a = sample_tri(tex, p + vec3(-13.0, 0.0, 21.0), n, scale * 0.045).rgb;
	float w_meso = 0.34 + 0.20 * fbm(p.xz * 0.009);
	float w_macro = 0.32 + 0.18 * fbm(p.xz * 0.0038 + 5.0);
	float w_patch = 0.22 * fbm(p.xz * 0.0022 + 14.0);
	return mix(mix(mix(detail, meso, w_meso), macro, w_macro), patch_a, w_patch);
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
	float gravel = smoothstep(0.58, 0.82, fbm(world_pos.xz * 0.019 + 8.2));
	float cobble = step(0.90, vnoise(world_pos.xz * 0.13 + 6.0));
	float mid = smoothstep(14.0, 36.0, radial) * (1.0 - smoothstep(95.0, 160.0, radial));
	vec3 albedo = sand * sand_w + dirt * dirt_w + rock * rock_w;
	albedo = mix(albedo, rock * 0.82, specks * 0.45 * (1.0 - rock_w));
	albedo = mix(albedo, sand * vec3(1.08, 0.96, 0.8), crust * 0.22 * (1.0 - rock_w));
	albedo = mix(albedo, mix(rock * vec3(0.96, 0.78, 0.56), sand * vec3(0.86, 0.62, 0.38), 0.35), gravel * 0.55 * (1.0 - rock_w) * (0.45 + 0.55 * mid));
	albedo = mix(albedo, rock * vec3(0.78, 0.58, 0.38), cobble * 0.62 * (1.0 - rock_w));

	float band = fract(world_pos.y * 0.62 + fbm(world_pos.xz * 0.018) * 0.16);
	float strata = smoothstep(0.0, 0.08, band) * (1.0 - smoothstep(0.18, 0.32, band));
	albedo = mix(albedo, rock * vec3(1.16, 0.90, 0.64), strata * rock_w * 0.55);
	albedo = mix(albedo, rock * vec3(0.68, 0.46, 0.30), strata * rock_w * 0.28 * step(0.5, band));

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
	vec3 ns_fine = sample_tri_stoch(sand_normal, world_pos, world_n, uv_scale * 3.2).rgb;
	vec2 d = sand_domain(world_pos);
	float rip_freq = mix(2.4, 5.8, fbm(world_pos.xz * 0.015 + 2.0));
	float rip = sin(d.x * rip_freq + fbm(world_pos.xz * 0.05) * 3.5);
	float rip_b = sin(d.y * (rip_freq * 0.62) + 1.7);
	float rip_w = 0.10 * sand_w * (1.0 - gravel) * (1.0 - mid * 0.35);
	vec3 nproc = vec3(rip * 0.5 + 0.5, rip_b * 0.5 + 0.5, 1.0);
	ns = mix(mix(ns, ns_fine, 0.38), nproc, rip_w);
	vec3 nd = sample_tri(dirt_normal, world_pos, world_n, uv_scale * 0.92).rgb;
	vec3 nr = sample_tri(rock_normal, world_pos, world_n, uv_scale * 0.48).rgb;
	vec3 nr_band = sample_tri(rock_normal, world_pos, world_n, uv_scale * 0.16).rgb;
	nr = mix(nr, nr_band, strata * 0.55);
	vec3 ngrav = sample_tri(rock_normal, world_pos, world_n, uv_scale * 1.15).rgb;
	ns = mix(ns, ngrav, gravel * 0.55 * (1.0 - rock_w));
	NORMAL_MAP = ns * sand_w + nd * dirt_w + nr * rock_w;
	NORMAL_MAP_DEPTH = mix(1.05, 0.12, haze);
}
