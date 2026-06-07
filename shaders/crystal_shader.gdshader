shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec3 crystal_color : source_color = vec3(0.4, 0.8, 1.0);
uniform float emission_energy : hint_range(0.0, 10.0) = 1.0;
uniform float facet_contrast : hint_range(0.0, 2.0) = 0.85;
uniform vec3 core_color : source_color = vec3(0.08, 0.35, 0.7);
uniform vec3 rim_color : source_color = vec3(0.92, 1.0, 1.0);

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

float hash31(vec3 p) {
	return fract(sin(dot(p, vec3(17.17, 61.43, 113.91))) * 43758.5453);
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);

	float vertical_gradient = smoothstep(-0.36, 0.42, local_pos.y);
	float center_shadow = smoothstep(0.42, 0.02, length(local_pos.xz));
	float edge = pow(1.0 - clamp(dot(normal, view_dir), 0.0, 1.0), 2.4);
	float top_light = clamp(local_normal.y * 0.5 + 0.5, 0.0, 1.0);

	float facet_id = floor((atan(local_pos.z, local_pos.x) + 3.14159) / 1.04719);
	float facet_noise = hash31(vec3(facet_id, floor(local_pos.y * 6.0), 2.0));
	float band = smoothstep(0.03, 0.18, abs(fract(local_pos.y * 5.2 + facet_noise * 0.35) - 0.5));
	float diagonal = smoothstep(0.0, 0.9, abs(sin((local_pos.x + local_pos.z + local_pos.y * 0.35) * 12.0)));
	float facet = mix(0.62, 1.28, facet_noise) * mix(0.78, 1.18, band) * mix(0.88, 1.08, diagonal);

	vec3 deep = core_color * crystal_color;
	vec3 body = mix(deep, crystal_color * 1.35, vertical_gradient);
	body = mix(body, rim_color, edge * 0.36 + top_light * 0.08);
	body *= mix(vec3(1.0), vec3(facet), facet_contrast);
	body = mix(body, rim_color, center_shadow * 0.06);

	float pulse = sin(TIME * 1.9) * 0.5 + 0.5;
	vec3 inner_glow = mix(core_color, crystal_color * 1.55, vertical_gradient);

	ALBEDO = body;
	EMISSION = inner_glow * emission_energy * (0.32 + pulse * 0.14 + edge * 0.72 + center_shadow * 0.18);
	ROUGHNESS = 0.16;
	METALLIC = 0.18;
	SPECULAR = 0.85;
	ALPHA = 0.94;
}
