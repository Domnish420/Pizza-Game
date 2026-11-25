shader_type canvas_item;
// One eye of a phone VR viewer (Cardboard-style). The viewer's lens bends the picture outwards (pincushion), so the
// picture is bent inwards (barrel) first and straight lines look straight through the lens. Outside the lens: black.

uniform float aspect = 0.889;       // the eye's width / height
uniform float k1 = 0.22;            // how strongly the lens bends (a typical viewer; Settings may tune it later)
uniform float k2 = 0.24;
uniform float fill = 0.8;           // how much of the eye's picture reaches the edge of the lens

void fragment() {
	vec2 c = (UV - 0.5) * 2.0;
	c.x *= aspect;
	float r2 = dot(c, c);
	vec2 d = c * (1.0 + k1 * r2 + k2 * r2 * r2) * fill;
	d.x /= aspect;
	vec2 uv = d * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		COLOR = vec4(texture(TEXTURE, uv).rgb, 1.0);
	}
}
