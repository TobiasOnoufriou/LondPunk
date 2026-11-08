// Opaque wall material that characters and the camera can see through.
// A drop-in for a basic StandardMaterial3D; tune the effect in SeeThroughSettings.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/see_through.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec2 uv_scale = vec2(1.0);

void fragment() {
    vec3 emission = vec3(0.0);
    if (see_through_cut(SCREEN_UV, VERTEX, VIEWPORT_SIZE, FRAGCOORD.xy, emission)) {
        discard;
    }
    ALBEDO = albedo_color.rgb * texture(albedo_texture, UV * uv_scale).rgb;
    ROUGHNESS = roughness;
    METALLIC = metallic;
    EMISSION = emission;
}
