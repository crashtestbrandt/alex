// THE SHAPE EVERY CONTROL WEARS: a rounded rectangle evaluated as a distance field per pixel, with its fill,
// a hairline border, a rim lit from above and a soft shadow below (docs/ui.md). A button, a panel, a tile and
// a pill bar are all this field at different sizes and radii.
//
// WHY A FIELD. A StyleBoxFlat's corner is a fan of triangles whose antialiasing is a feather in local units,
// so it softens or hardens with the UI scale and the radius. Evaluated analytically, the edge covers exactly
// its share of every pixel at every scale, and the rim and the shadow are the same field read at an offset,
// not extra geometry. Same coverage law as spaceman's HUD strokes.
//
// GEOMETRY IN CONTROL UNITS. `rect_px` is the drawn quad, which is the control grown by `pad_px` on every
// side so the shadow has somewhere to fall. The field is evaluated from UV, not FRAGCOORD, so it survives any
// canvas transform.
shader_type canvas_item;

uniform vec2 rect_px = vec2(1.0);
uniform float pad_px = 0.0;
uniform float radius_px = 18.0;
uniform vec4 fill : source_color = vec4(1.0);
uniform vec4 border : source_color = vec4(0.0);
uniform float border_px = 0.0;
uniform vec4 shadow : source_color = vec4(0.0, 0.0, 0.0, 0.3);
uniform float shadow_px = 14.0;
uniform vec2 shadow_offset_px = vec2(0.0, 5.0);
// 0 is flat: no rim, no shadow. 1 is the full relief. A style preset sets it.
uniform float relief = 0.6;
// 0 at rest, 1 fully pressed: the shape pulls in by PRESS_INSET_PX.
uniform float press = 0.0;

const float EPS = 0.0001;
const float PRESS_INSET_PX = 3.0;
const float RIM_PX = 3.0;
const float RIM_LIGHT = 0.42;
const float RIM_SHADE = 0.18;

varying vec4 v_modulate;

float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// Coverage of a fill whose boundary is the zero level set, for a pixel footprint `fw`.
float cover(float sd, float fw) {
	return clamp(0.5 - sd / fw, 0.0, 1.0);
}

// The outward normal of the rounded box at p: radial in a corner, axis-aligned on a side.
vec2 box_normal(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	vec2 s = sign(p);
	if (q.x > 0.0 || q.y > 0.0) {
		return normalize(s * max(q, vec2(0.0)) + vec2(EPS));
	}
	return (q.x > q.y) ? vec2(s.x, 0.0) : vec2(0.0, s.y);
}

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec2 p = UV * rect_px - rect_px * 0.5;
	float fw = max(fwidth(p.x) + fwidth(p.y), EPS);
	vec2 b = rect_px * 0.5 - vec2(pad_px) - vec2(PRESS_INSET_PX * press);
	float r = clamp(radius_px, 0.0, min(b.x, b.y));
	float sd = rounded_box(p, b, r);

	float a_fill = cover(sd, fw) * fill.a;
	float a_border = 0.0;
	if (border_px > 0.0) {
		a_border = cover(abs(sd + border_px * 0.5) - border_px * 0.5, fw) * border.a;
	}

	// The rim: a band just inside the edge, lit where the normal faces up the screen, shaded where it faces down.
	float band = clamp(1.0 + sd / RIM_PX, 0.0, 1.0) * cover(sd, fw);
	vec2 n = box_normal(p, b, r);
	float lit = max(0.0, -n.y) * band * RIM_LIGHT * relief;
	float shaded = max(0.0, n.y) * band * RIM_SHADE * relief;
	vec3 rgb = mix(fill.rgb, vec3(1.0), lit);
	rgb = mix(rgb, vec3(0.0), shaded);
	rgb = mix(rgb, border.rgb, a_border);
	float alpha = max(a_fill, a_border);

	// The shadow: the same field, offset, blurred over shadow_px, only where the shape itself is not.
	float sd_shadow = rounded_box(p - shadow_offset_px * relief, b, r);
	float shade = shadow.a * relief * (1.0 - smoothstep(-shadow_px * 0.25, shadow_px, sd_shadow)) * (1.0 - alpha);

	float out_a = alpha + shade;
	vec3 out_rgb = (rgb * alpha + shadow.rgb * shade) / max(out_a, EPS);
	COLOR = vec4(out_rgb * v_modulate.rgb, out_a * v_modulate.a);
}
