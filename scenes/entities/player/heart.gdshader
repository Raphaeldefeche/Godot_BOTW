shader_type canvas_item;

uniform vec3 color: source_color = vec3(1.0);
uniform float progress: hint_range(0.0, 1.0) = 0.0;
uniform float alpha: hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);
	COLOR.rgb = mix(texture_color.rgb, color, progress);
	COLOR.a = alpha * texture_color.a;
}