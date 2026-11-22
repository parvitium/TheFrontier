shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled, specular_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.72, 0.32, 1.0);
uniform float glow = 2.4;
uniform float softness = 1.55;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radial = length(centered) * 2.0;
	float grain = fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453);
	float mask = pow(clamp(1.0 - radial, 0.0, 1.0), softness);
	mask *= mix(0.82, 1.0, grain);
	vec3 col = tint.rgb * COLOR.rgb;
	ALBEDO = col;
	EMISSION = col * glow;
	ALPHA = mask * COLOR.a * tint.a;
}
