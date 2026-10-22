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
uniform float uv_scale : hint_range(0.02, 1.0) = 0.12;
uniform float rock_slope : hint_range(0.1, 1.0) = 0.42;
uniform vec3 sand_tint = vec3(1.02, 0.92, 0.78);
uniform vec3 dirt_tint = vec3(0.92, 0.82, 0.7);

varying vec3 world_pos;
varying vec3 world_n;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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

void fragment() {
	float slope = 1.0 - clamp(world_n.y, 0.0, 1.0);
	float rock_w = smoothstep(0.12, rock_slope, slope);
	float radial = length(world_pos.xz);
	float sand_w = smoothstep(10.0, 30.0, radial) * (1.0 - rock_w);
	float dirt_w = clamp(1.0 - rock_w - sand_w, 0.0, 1.0);

	vec3 sand = sample_tri(sand_albedo, world_pos, world_n, uv_scale).rgb * sand_tint;
	vec3 dirt = sample_tri(dirt_albedo, world_pos, world_n, uv_scale * 0.9).rgb * dirt_tint;
	vec3 rock = sample_tri(rock_albedo, world_pos, world_n, uv_scale * 0.55).rgb;
	ALBEDO = sand * sand_w + dirt * dirt_w + rock * rock_w;

	float rs = sample_tri(sand_rough, world_pos, world_n, uv_scale).r;
	float rd = sample_tri(dirt_rough, world_pos, world_n, uv_scale * 0.9).r;
	float rr = sample_tri(rock_rough, world_pos, world_n, uv_scale * 0.55).r;
	ROUGHNESS = clamp(rs * sand_w + rd * dirt_w + rr * rock_w, 0.2, 1.0);
	METALLIC = 0.02 * (1.0 - rock_w);

	vec3 ns = sample_tri(sand_normal, world_pos, world_n, uv_scale).rgb;
	vec3 nd = sample_tri(dirt_normal, world_pos, world_n, uv_scale * 0.9).rgb;
	vec3 nr = sample_tri(rock_normal, world_pos, world_n, uv_scale * 0.55).rgb;
	NORMAL_MAP = ns * sand_w + nd * dirt_w + nr * rock_w;
	NORMAL_MAP_DEPTH = 0.85;
}
