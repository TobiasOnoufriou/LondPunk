// See-through walls. Include in any spatial shader and, in fragment():
//
//     if (see_through_cut(SCREEN_UV, VERTEX, VIEWPORT_SIZE, FRAGCOORD.xy, EMISSION)) {
//         discard;
//     }
//
// The globals are declared in project.godot and driven by SeeThroughController.

// xy = target screen position (0..1), z = view depth, w = screen radius (fraction of height).
global uniform vec4 see_through_target_0;
global uniform vec4 see_through_target_1;
global uniform vec4 see_through_target_2;
global uniform vec4 see_through_target_3;
global uniform vec4 see_through_target_4;
global uniform vec4 see_through_target_5;
global uniform vec4 see_through_target_6;
global uniform vec4 see_through_target_7;
global uniform int see_through_count;

global uniform bool see_through_cutout_enabled;
global uniform sampler2D see_through_mask;
global uniform float see_through_mask_threshold;
global uniform float see_through_edge_softness;
global uniform vec4 see_through_edge_color;
global uniform float see_through_edge_width;
global uniform float see_through_depth_bias;

global uniform bool see_through_near_enabled;
global uniform float see_through_near_distance;
global uniform float see_through_near_softness;

// Screen-space dither in 0..1 (interleaved gradient noise).
float see_through_noise(vec2 frag_coord) {
    return fract(52.9829189 * fract(dot(frag_coord, vec2(0.06711056, 0.00583715))));
}

// Returns true when the fragment should be discarded. Adds the cutout rim to emission.
bool see_through_cut(vec2 screen_uv, vec3 view_vertex, vec2 viewport_size, vec2 frag_coord, inout vec3 emission) {
    float noise = see_through_noise(frag_coord);

    if (see_through_near_enabled) {
        float softness = max(see_through_near_softness, 0.001);
        float keep = smoothstep(see_through_near_distance - softness, see_through_near_distance, length(view_vertex));
        if (keep < noise) {
            return true;
        }
    }

    if (!see_through_cutout_enabled || see_through_count <= 0) {
        return false;
    }

    vec4 targets[8] = vec4[8](
        see_through_target_0, see_through_target_1, see_through_target_2, see_through_target_3,
        see_through_target_4, see_through_target_5, see_through_target_6, see_through_target_7);
    float aspect = viewport_size.x / viewport_size.y;
    float depth = -view_vertex.z;
    float softness = max(see_through_edge_softness, 0.001);
    float rim = 0.0;

    for (int i = 0; i < min(see_through_count, 8); i++) {
        vec4 target = targets[i];
        if (target.w <= 0.0 || depth > target.z - see_through_depth_bias) {
            continue;
        }
        vec2 offset = (screen_uv - target.xy) * vec2(aspect, 1.0) / target.w;
        vec2 mask_uv = offset * 0.5 + 0.5;
        if (any(lessThan(mask_uv, vec2(0.0))) || any(greaterThan(mask_uv, vec2(1.0)))) {
            continue;
        }
        vec4 mask = texture(see_through_mask, mask_uv);
        float value = mask.r * mask.a;
        float keep = smoothstep(see_through_mask_threshold - softness, see_through_mask_threshold + softness, value);
        if (keep < noise) {
            return true;
        }
        if (see_through_edge_width > 0.0) {
            float edge_start = see_through_mask_threshold + softness;
            // Thin band peaking where the dithered edge ends.
            float band = smoothstep(edge_start - see_through_edge_width, edge_start, value)
                * (1.0 - smoothstep(edge_start, edge_start + see_through_edge_width, value));
            rim = max(rim, band);
        }
    }

    emission += see_through_edge_color.rgb * see_through_edge_color.a * rim;
    return false;
}
