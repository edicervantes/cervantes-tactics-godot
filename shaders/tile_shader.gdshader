shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D base_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 zone_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.5;
uniform bool is_corrupted = false; // Kept for backwards compatibility
uniform vec2 map_size = vec2(12.0, 9.0);
uniform vec3 corruption_color : source_color = vec3(0.14, 0.04, 0.20);
uniform vec3 corruption_emission : source_color = vec3(0.15, 0.05, 0.25);
uniform bool is_grass_terrace = false;
uniform bool is_dais = false;
uniform bool is_prop = false;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float line_mask(float distance_to_line, float thickness) {
	return 1.0 - smoothstep(thickness, thickness * 1.8, distance_to_line);
}

void fragment() {
	vec3 norm = normalize(world_normal);
	vec3 blend = abs(norm);
	blend /= (blend.x + blend.y + blend.z + 0.0001);

	// Triplanar texture mapping (rotated and scaled for natural tiling)
	vec2 uv_x = world_pos.zy * 0.22;
	vec2 uv_y = world_pos.xz * 0.22;
	vec2 uv_z = world_pos.xy * 0.22;

	vec3 tex_x = texture(base_texture, uv_x).rgb;
	vec3 tex_y = texture(base_texture, uv_y).rgb;
	vec3 tex_z = texture(base_texture, uv_z).rgb;

	vec3 stone_color = tex_x * blend.x + tex_y * blend.y + tex_z * blend.z;

	if (norm.y > 0.5) {
		// Top Surface
		vec3 tinted = mix(stone_color, stone_color * zone_tint, tint_strength);

		if (is_grass_terrace) {
			// Moss green overlay
			vec3 moss_color = vec3(0.18, 0.32, 0.12);
			// Blend moss based on the stone texture color highlights (making it grow in crevices or on top)
			float moss_factor = smoothstep(0.2, 0.8, 1.0 - (stone_color.r + stone_color.g + stone_color.b) * 0.33);
			tinted = mix(tinted, moss_color * (stone_color * 1.6), moss_factor * 0.55 + 0.18);
		}

		ALBEDO = tinted;
		float stone_gray = (stone_color.r + stone_color.g + stone_color.b) * 0.333;
		ROUGHNESS = mix(0.92, 0.58, smoothstep(0.2, 0.7, stone_gray));
		METALLIC = 0.04;

		// Global Spatial Corruption Fade
		// The map starts at 0,0. Assuming enemies come from +X (right side).
		float fade_start = map_size.x * 0.25;
		float fade_end = map_size.x + 0.5;
		float fade = smoothstep(fade_start, fade_end, world_pos.x);
		
		// Add some organic noise to the fade boundary
		float noise_val = fract(sin(dot(world_pos.xz, vec2(12.9898, 78.233))) * 43758.5453);
		// A slow crawling wave to make the edge irregular
		float wave = sin(world_pos.z * 1.5) * 0.5 + sin(world_pos.z * 3.1) * 0.25;
		float organic_fade = fade > 0.001 ? clamp(fade + wave * 0.12 + (noise_val - 0.5) * 0.12, 0.0, 1.0) : 0.0;

		if (!is_prop && organic_fade > 0.0) {
			// Mix ALBEDO with corruption color, preserving the stone details
			// Multiplier reduced to 1.2 to create a very dark shadow at the edges
			ALBEDO = mix(ALBEDO, ALBEDO * corruption_color * 1.2, organic_fade);
			
			// Add very subtle emission in the dark cracks of the stone
			float stone_darkness = 1.0 - clamp(stone_gray * 1.5, 0.0, 1.0);
			EMISSION = mix(EMISSION, corruption_emission * stone_darkness * 0.8, organic_fade);
		}

		if (is_dais && abs(norm.y) > 0.9) {
			vec2 cell_center = floor(world_pos.xz) + vec2(0.5);
			vec2 local_pos = world_pos.xz - cell_center;
			float dist = length(local_pos);
			float thickness = 0.009;

			// Circular gold inlays
			float r1 = line_mask(abs(dist - 0.35), thickness);
			float r2 = line_mask(abs(dist - 0.18), thickness * 0.8);
			
			// Radial gold spokes
			float angle = atan(local_pos.y, local_pos.x);
			float spokes = line_mask(abs(sin(angle * 4.0)), 0.03) * step(dist, 0.35) * step(0.18, dist);

			float gold_mask = max(max(r1, r2), spokes);
			ALBEDO = mix(ALBEDO, vec3(0.72, 0.56, 0.28), gold_mask * 0.9);
			METALLIC = mix(METALLIC, 0.6, gold_mask);
			ROUGHNESS = mix(ROUGHNESS, 0.3, gold_mask);
		}
	} else {
		// Sides / Cliffs
		if (is_prop) {
			ALBEDO = stone_color * zone_tint * 0.80;
			ROUGHNESS = 0.88;
			METALLIC = 0.04;
		} else {
			float vertical_grad = smoothstep(-1.2, 0.8, world_pos.y);
			vec3 tinted_side = mix(stone_color * 0.14, stone_color * 0.32 * zone_tint, vertical_grad);

			ALBEDO = tinted_side;
			ROUGHNESS = 0.9;
			METALLIC = 0.02;
		}
	}
}
