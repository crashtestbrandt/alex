shader_type canvas_item;
render_mode unshaded;

// Probe-only simulation of rounded display edges, a cutout and the gesture indicator.
uniform vec2 screen_size;
uniform vec4 cutout;
uniform float corner_radius = 48.0;

float rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 p = UV * screen_size;
	float edge = rounded_box(p - screen_size * 0.5, screen_size * 0.5, corner_radius);
	float hole = rounded_box(p - cutout.xy - cutout.zw * 0.5, cutout.zw * 0.5, min(min(cutout.z, cutout.w) * 0.5, 18.0));
	float gesture = rounded_box(p - vec2(screen_size.x * 0.5, screen_size.y - 9.0), vec2(65.0, 2.5), 2.5);
	float alpha = max(smoothstep(-0.5, 0.5, edge), max(1.0 - smoothstep(-0.5, 0.5, hole), 1.0 - smoothstep(-0.5, 0.5, gesture)));
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
