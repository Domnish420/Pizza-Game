shader_type spatial;
// The pizza (Pizza3D). The mesh carries the dough: its colour (browned crust) in the vertex colour, in sRGB.
// What is on it comes from a small map of the pizza's sauce and cheese grid (one pixel per cell: R sauce, G cheese)
// and is drawn here per pixel: sauce that is glossy and darker where it is thick, cheese that is shreds when raw and
// melted pools with golden blisters once baked, and leopard-spot char on the crust when the oven has pushed it.
// UV is where a point falls on the layer map; UV2.x is 1 on the flat middle and 0 on the crust; UV2.y is how much
// that point is the top of the crust. The bake is a uniform (12 sectors round the edge, 1 = done, as Pizza.bake), so
// the pizza browns in the oven without its mesh being rebuilt.

uniform sampler2D layers : filter_linear, repeat_disable;
uniform vec3 sauce_col : source_color = vec3(0.8, 0.2, 0.1);
uniform vec3 cheese_col : source_color = vec3(0.97, 0.94, 0.85);
uniform float melt = 0.0;       // 0 raw cheese .. 1 fully melted
uniform float mid_b = 0.0;      // how browned the middle is
uniform float seed = 0.0;
uniform float max_amt = 2.5;
uniform float bake[12];
uniform float spots[12];        // leopard spots per crust sector (Pizza.spots: 0 none, 1 a good spotting, more scorched)
uniform vec3 holes[3];          // holes torn through the base (PizzaBase.holes: xy where, z how wide), n_holes of them
uniform int n_holes = 0;

varying vec2 pp;

void vertex() {
	pp = VERTEX.xz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// the browning of dough for a doneness value (in sRGB): golden by done, a little deeper just past it, then brown and black
vec3 brown(vec3 c, float b, vec3 golden) {
	if (b <= 0.0) return c;
	if (b < 1.0) return mix(c, golden, b * 0.9);
	vec3 g = mix(c, golden, 0.9);
	if (b < 1.15) return g;
	vec3 dark = vec3(0.431, 0.231, 0.102);
	if (b < 1.45) return mix(g, dark, (b - 1.15) / 0.3);
	return mix(dark, vec3(0.184, 0.114, 0.071), clamp((b - 1.45) / 0.35, 0.0, 1.0));
}

float bake_at(vec2 p) {
	float f = fract(atan(p.y, p.x) / 6.2831853) * 12.0;
	int i = int(floor(f)) % 12;
	float k = f - floor(f);
	return mix(bake[i], bake[(i + 1) % 12], k);
}

float spots_at(vec2 p) {
	float f = fract(atan(p.y, p.x) / 6.2831853) * 12.0;
	int i = int(floor(f)) % 12;
	float k = f - floor(f);
	return mix(spots[i], spots[(i + 1) % 12], k);
}

void fragment() {
	// a hole torn through: nothing there, a ragged edge, the dough round it stretched thin and a little darker
	float lip = 0.0;
	for (int i = 0; i < 3; i++) {
		if (i >= n_holes) break;
		vec2 d = pp - holes[i].xy;
		float l = length(d);
		float rr = holes[i].z * (0.7 + 0.6 * vnoise(d / max(l, 0.001) * 2.2 + float(i) * 7.0));
		if (l < rr) discard;
		lip = max(lip, 1.0 - smoothstep(rr, rr * 1.6, l));
	}
	float inner = clamp(UV2.x, 0.0, 1.0);
	float top = UV2.y;
	float edge_b = bake_at(pp);
	float crust_b = edge_b * (0.6 + 0.45 * top);
	vec3 raw = COLOR.rgb;
	vec3 baked_col = mix(brown(raw, edge_b * (0.9 + 0.12 * top), vec3(0.812, 0.561, 0.247)), brown(raw, mid_b, vec3(0.886, 0.718, 0.4)), inner);
	vec3 col = pow(baked_col, vec3(2.2));
	vec4 L = texture(layers, UV);
	float sa = L.r * max_amt * smoothstep(0.55, 0.95, inner);
	float ca = L.g * max_amt * smoothstep(0.55, 0.95, inner);
	float gloss = 0.0;
	// sauce: a smooth layer, ragged at its edge, darker and redder where it is laid thick
	float edge = (vnoise(pp * 0.18) - 0.5) * 0.35;
	float sm = smoothstep(0.08, 0.45, sa + edge);
	vec3 sc = mix(sauce_col, sauce_col * vec3(0.78, 0.7, 0.68), smoothstep(1.1, 2.2, sa));
	sc *= 1.0 - 0.18 * clamp(mid_b, 0.0, 1.0);
	col = mix(col, sc, sm);
	gloss = max(gloss, sm * 0.8 * (1.0 - 0.45 * clamp(mid_b, 0.0, 1.0)));
	// cheese: raw shreds, or melted pools with golden blisters
	vec2 q = pp;
	// shreds: thin strands at two crossing angles, more of them where more cheese went on
	vec2 r1 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * q;
	vec2 r2 = mat2(vec2(0.28, -0.96), vec2(0.96, 0.28)) * q;
	float s1 = vnoise(vec2(r1.x * 0.9, r1.y * 0.16));
	float s2 = vnoise(vec2(r2.x * 0.9, r2.y * 0.16) + 5.0);
	float dens = clamp(ca, 0.0, 1.6);
	float th = 0.78 - dens * 0.2;
	float shred = max(smoothstep(th, th + 0.04, s1), smoothstep(th + 0.02, th + 0.06, s2));
	shred *= smoothstep(0.05, 0.25, ca);
	// melted: pools that run together where it is thick, with soft golden variation
	float pool = smoothstep(0.32, 0.55, ca * 0.75 + (vnoise(q * 0.08) - 0.5) * 0.6 + (vnoise(q * 0.25) - 0.5) * 0.15);
	float cm = mix(shred, pool, melt);
	vec3 cc = cheese_col * mix(1.05, 0.98, melt);
	cc = mix(cc, cc * vec3(1.0, 0.9, 0.72), melt * smoothstep(0.4, 0.9, vnoise(q * 0.06 + 9.0)) * 0.5);
	float blister = smoothstep(0.68, 0.74, vnoise(q * 0.2 + 3.0)) * smoothstep(0.6, 0.95, mid_b) * melt;
	cc = mix(cc, vec3(0.78, 0.5, 0.2), blister * 0.75);
	col = mix(col, cc, cm);
	gloss = max(gloss, cm * mix(0.15, 0.85, melt));
	// leopard spots on the crust where the flames blistered it (Pizza.spots): more and bigger spots the harder each side
	// was hit; far too much and the side is scorched
	float sp = spots_at(pp);
	float lc = (1.0 - inner) * smoothstep(0.02, 0.15, sp);
	float spot = smoothstep(0.84 - 0.16 * clamp(sp, 0.0, 1.5), 0.88 - 0.16 * clamp(sp, 0.0, 1.5), vnoise(pp * 0.3 + 11.0)) * lc;
	col = mix(col, vec3(0.03, 0.02, 0.015), spot * 0.92);
	col = mix(col, vec3(0.04, 0.03, 0.02), (1.0 - inner) * smoothstep(1.8, 2.8, sp) * 0.75);
	col = mix(col, col * vec3(0.8, 0.72, 0.62), lip * 0.7);
	ALBEDO = col;
	ROUGHNESS = mix(0.86, 0.24, gloss);
	SPECULAR = mix(0.25, 0.7, gloss);
}
