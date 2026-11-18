shader_type canvas_item;
// The "Retro" look (the phone's Today page): the 3D view is drawn at half resolution by the view itself, and this
// pass gives it fewer colour levels with a 4x4 ordered dither, like a 2000s console on a TV.
uniform float levels = 28.0;
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	float d = (BAYER[y * 4 + x] / 16.0 - 0.5) / levels;
	COLOR = vec4(floor((c.rgb + d) * levels + 0.5) / levels, c.a);
}
