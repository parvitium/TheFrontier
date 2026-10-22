shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 rock_tint = vec3(0.98, 0.84, 0.64);
uniform vec3 sand_tint = vec3(1.08, 0.88, 0.58);
uniform float uv_scale = 0.48;

varying vec3 world_pos;
varying vec3 world_n;
varying float local_y;
varying float local_h;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	local_y = VERTEX.y;
	local_h = max(length(MODEL_MATRIX[1].xyz), 0.18);
}

vec4 sample_tri(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 blending = abs(n);
	blending = pow(blending, vec3(3.0));
	blending /= (blending.x + blending.y + blending.z + 1e-5);
	return texture(tex, p.yz * scale) * blending.x
		+ texture(tex, p.xz * scale) * blending.y
		+ texture(tex, p.xy * scale) * blending.z;
}

void fragment() {
	float up = clamp(world_n.y, 0.0, 1.0);
	float sand_w = smoothstep(0.16, 0.62, up) * (1.0 - smoothstep(0.10, 0.46, local_y / local_h));
	sand_w = clamp(sand_w, 0.0, 0.82);
	vec3 rock = sample_tri(rock_albedo, world_pos, world_n, uv_scale).rgb * rock_tint;
	vec3 sand = sample_tri(sand_albedo, world_pos, world_n, uv_scale * 0.72).rgb * sand_tint;
	float band = fract(world_pos.y * 1.22 + world_pos.x * 0.018 + world_pos.z * 0.014);
	float strata = smoothstep(0.0, 0.07, band) * (1.0 - smoothstep(0.16, 0.30, band));
	rock = mix(rock, rock * vec3(1.14, 0.92, 0.70), strata * 0.38);
	rock = mix(rock, rock * vec3(0.76, 0.56, 0.38), strata * 0.22 * step(0.5, band));
	ALBEDO = mix(rock, sand, sand_w);
	float rr = sample_tri(rock_rough, world_pos, world_n, uv_scale).r;
	ROUGHNESS = clamp(mix(max(rr, 0.55) * 1.12, 0.94, sand_w), 0.50, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.08;
	vec3 nr = sample_tri(rock_normal, world_pos, world_n, uv_scale).rgb;
	vec3 ns = sample_tri(sand_normal, world_pos, world_n, uv_scale * 0.72).rgb;
	NORMAL_MAP = mix(nr, ns, sand_w);
	NORMAL_MAP_DEPTH = 0.72;
}
