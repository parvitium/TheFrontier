shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled, specular_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.38, 1.0);
uniform float fade = 1.0;
uniform float glow = 3.2;
uniform float core_width = 0.22;

void fragment() {
	float along = UV.y;
	float across = abs(UV.x - 0.5) * 2.0;
	float shaft = smoothstep(1.0, core_width, across);
	float head = smoothstep(0.0, 0.12, along) * (1.0 - smoothstep(0.72, 1.0, along));
	vec3 col = tint.rgb * COLOR.rgb;
	float a = shaft * head * fade * tint.a * COLOR.a;
	ALBEDO = col;
	EMISSION = col * glow;
	ALPHA = a;
}
