// THE GLYPHS ON THE LEARNER'S BUTTONS: the front, side, top and tilt views, three dots (unused), and the
// microphone. Each is a composition of segments, boxes, arcs and discs evaluated as a
// distance field per pixel, so a stroke covers exactly its share of every pixel at every scale (docs/ui.md).
// `figure` picks the composition, so every glyph shares one shader and one uniform set. A figure added later
// is a case here plus a value in [enum SdfGlyph.Figure].
shader_type canvas_item;

uniform vec2 rect_px = vec2(1.0);
// The glyph's radius: half of the figure's longer side, in control units.
uniform float radius_px = 20.0;
uniform float width_px = 3.0;
// 0 front, 1 side, 2 top, 3 tilt (a circular arrow), 4 dots, 5 microphone, 6 palette, 7 build, 8 rooms, 9 back.
uniform int figure = 0;
uniform vec4 tint : source_color = vec4(1.0);

const float EPS = 0.0001;

varying vec4 v_modulate;

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), EPS), 0.0, 1.0);
	return distance(p, a + ab * t);
}

float box_edge(vec2 p, vec2 c, vec2 half_size, float r) {
	vec2 q = abs(p - c) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// Distance to an arc of radius r about the origin, from angle a0 to a1 (radians, screen y down).
float arc_distance(vec2 p, float r, float a0, float a1) {
	float ang = atan(p.y, p.x);
	float mid = (a0 + a1) * 0.5;
	float half_span = (a1 - a0) * 0.5;
	float d = ang - mid;
	d = d - 6.2831853 * floor((d + 3.1415927) / 6.2831853);
	if (abs(d) <= half_span) {
		return abs(length(p) - r);
	}
	vec2 e0 = vec2(cos(a0), sin(a0)) * r;
	vec2 e1 = vec2(cos(a1), sin(a1)) * r;
	return min(distance(p, e0), distance(p, e1));
}

float stroke(float edge, float width, float fw) {
	float sd = abs(edge) - width * 0.5;
	return clamp(0.5 - sd / fw, 0.0, min(1.0, max(width, 0.0) / fw));
}

float fill(float sd, float fw) {
	return clamp(0.5 - sd / fw, 0.0, 1.0);
}

float front_view(vec2 p, float r, float w, float fw) {
	// The room from the open front: a frame, and the floor's near edge drawn as a trapezoid below the back wall.
	float frame = stroke(box_edge(p, vec2(0.0, -0.05 * r), vec2(r, 0.75 * r), 0.12 * r), w, fw);
	vec2 bl = vec2(-r, 0.7 * r);
	vec2 br = vec2(r, 0.7 * r);
	vec2 il = vec2(-0.55 * r, 0.2 * r);
	vec2 ir = vec2(0.55 * r, 0.2 * r);
	float floor_lines = min(segment_distance(p, bl, il), min(segment_distance(p, br, ir), segment_distance(p, il, ir)));
	return max(frame, stroke(floor_lines, w, fw));
}

float side_view(vec2 p, float r, float w, float fw) {
	// A wall face-on and the back wall foreshortened beside it.
	float face = stroke(box_edge(p, vec2(-0.55 * r, 0.0), vec2(0.4 * r, 0.7 * r), 0.0), w, fw);
	vec2 a = vec2(-0.15 * r, -0.7 * r);
	vec2 b = vec2(0.95 * r, -0.4 * r);
	vec2 c = vec2(0.95 * r, 0.95 * r);
	vec2 d = vec2(-0.15 * r, 0.65 * r);
	float slant = min(min(segment_distance(p, a, b), segment_distance(p, b, c)), min(segment_distance(p, c, d), segment_distance(p, d, a)));
	return max(face, stroke(slant, w, fw));
}

float top_view(vec2 p, float r, float w, float fw) {
	// The floor plan: the room's outline, a bed, and a round thing.
	float outline = stroke(box_edge(p, vec2(0.0), vec2(r, 0.7 * r), 0.0), w, fw);
	float bed = stroke(box_edge(p, vec2(-0.4 * r, 0.0), vec2(0.25 * r, 0.3 * r), 0.0), w, fw);
	float dot = fill(length(p - vec2(0.5 * r, 0.1 * r)) - 0.18 * r, fw);
	return max(max(outline, bed), dot);
}

float turn_view(vec2 p, float r, float w, float fw) {
	// A circular arrow.
	float ring = stroke(arc_distance(p, r * 0.8, 0.4, 5.3), w, fw);
	vec2 tip = vec2(cos(0.4), sin(0.4)) * r * 0.8;
	vec2 dir = vec2(-sin(0.4), cos(0.4));
	vec2 side = vec2(cos(0.4), sin(0.4));
	float head = min(segment_distance(p, tip, tip - dir * 0.45 * r - side * 0.3 * r), segment_distance(p, tip, tip - dir * 0.45 * r + side * 0.3 * r));
	return max(ring, stroke(head, w, fw));
}

float dots(vec2 p, float r, float fw) {
	float d = min(length(p - vec2(-0.6 * r, 0.0)), min(length(p), length(p - vec2(0.6 * r, 0.0))));
	return fill(d - 0.16 * r, fw);
}

float microphone(vec2 p, float r, float w, float fw) {
	// A capsule head, the cradle arc under it, the stem and the base.
	float head = fill(segment_distance(p, vec2(0.0, -0.75 * r), vec2(0.0, -0.1 * r)) - 0.3 * r, fw);
	float cradle = stroke(arc_distance(p - vec2(0.0, -0.1 * r), 0.55 * r, 0.0, 3.1415927), w, fw);
	float stem = stroke(segment_distance(p, vec2(0.0, 0.45 * r), vec2(0.0, 0.8 * r)), w, fw);
	float base = stroke(segment_distance(p, vec2(-0.4 * r, 0.8 * r), vec2(0.4 * r, 0.8 * r)), w, fw);
	return max(max(head, cradle), max(stem, base));
}

float palette_view(vec2 p, float r, float w, float fw) {
	// A column of two tiles.
	float upper = stroke(box_edge(p, vec2(0.0, -0.48 * r), vec2(0.9 * r, 0.34 * r), 0.12 * r), w, fw);
	float lower = stroke(box_edge(p, vec2(0.0, 0.48 * r), vec2(0.9 * r, 0.34 * r), 0.12 * r), w, fw);
	return max(upper, lower);
}

float build_view(vec2 p, float r, float w, float fw) {
	// A chunk on the strip beside the slot for the next one.
	float placed = fill(box_edge(p, vec2(-0.5 * r, 0.0), vec2(0.42 * r, 0.26 * r), 0.26 * r), fw);
	float slot = stroke(box_edge(p, vec2(0.52 * r, 0.0), vec2(0.42 * r, 0.26 * r), 0.26 * r), w, fw);
	return max(placed, slot);
}

float rooms_view(vec2 p, float r, float w, float fw) {
	float d = 10000.0;
	for (int x = -1; x <= 1; x += 2) {
		for (int y = -1; y <= 1; y += 2) {
			d = min(d, abs(box_edge(p, vec2(float(x), float(y)) * r * 0.52, vec2(r * 0.39), r * 0.06)));
		}
	}
	return stroke(d, w, fw);
}

float back_view(vec2 p, float r, float w, float fw) {
	float d = segment_distance(p, vec2(-0.85 * r, 0.0), vec2(0.85 * r, 0.0));
	d = min(d, segment_distance(p, vec2(-0.85 * r, 0.0), vec2(-0.1 * r, -0.7 * r)));
	d = min(d, segment_distance(p, vec2(-0.85 * r, 0.0), vec2(-0.1 * r, 0.7 * r)));
	return stroke(d, w, fw);
}

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec2 p = UV * rect_px - rect_px * 0.5;
	float fw = max(fwidth(p.x) + fwidth(p.y), EPS);
	float a = 0.0;
	if (figure == 1) {
		a = side_view(p, radius_px, width_px, fw);
	} else if (figure == 2) {
		a = top_view(p, radius_px, width_px, fw);
	} else if (figure == 3) {
		a = turn_view(p, radius_px, width_px, fw);
	} else if (figure == 4) {
		a = dots(p, radius_px, fw);
	} else if (figure == 5) {
		a = microphone(p, radius_px, width_px, fw);
	} else if (figure == 6) {
		a = palette_view(p, radius_px, width_px, fw);
	} else if (figure == 7) {
		a = build_view(p, radius_px, width_px, fw);
	} else if (figure == 8) {
		a = rooms_view(p, radius_px, width_px, fw);
	} else if (figure == 9) {
		a = back_view(p, radius_px, width_px, fw);
	} else {
		a = front_view(p, radius_px, width_px, fw);
	}
	COLOR = vec4(tint.rgb * v_modulate.rgb, a * tint.a * v_modulate.a);
}
