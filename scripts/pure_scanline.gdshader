// Adapted from leon4aka's Retro TV shader under the CC0 license
// https://godotshaders.com/shader/retro-tv-shader/
shader_type canvas_item;

uniform float scanline_count : hint_range(0, 1800) = 180.0;
uniform float effect_intensity: hint_range(0.0, 1.0) = 0.5;
uniform float red_abberation: hint_range(-10, 10) = 0;
uniform float green_abberation: hint_range(-10, 10) = 2;
uniform float blue_abberation: hint_range(-10, 10) = -2;

void fragment()
{	
	float PI = 3.14159;
	
	//You can modify the *3.0, *-3.0 for a bigger or smaller 
	float r = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(SCREEN_PIXEL_SIZE.x * red_abberation), 0.0).r;
	float g = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(SCREEN_PIXEL_SIZE.x * green_abberation), 0.0).g;
	float b = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(SCREEN_PIXEL_SIZE.x * blue_abberation), 0.0).b;
	
	
	//If you dont want scanlines you can just delete this part
	float s = sin(SCREEN_UV.y * scanline_count * PI * 2.0);
	s = (s * 0.5 + 0.5) * 0.9 + 0.1;
	vec4 scan_line = vec4(vec3(pow(s, 0.25)), effect_intensity);
	
	
	COLOR = vec4(r, g, b, 1.0) * scan_line;
}
