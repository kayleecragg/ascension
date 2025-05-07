extern Image texture;

#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

extern MY_HIGHP_OR_MEDIUMP number dissolve;
extern MY_HIGHP_OR_MEDIUMP number time;
extern bool shadow;
extern MY_HIGHP_OR_MEDIUMP vec4 burn_colour_1;
extern MY_HIGHP_OR_MEDIUMP vec4 burn_colour_2;

vec4 dissolve_mask(vec4 tex, vec2 uv)
{
    if (dissolve < 0.001) {
        return vec4(shadow ? vec3(0.,0.,0.) : tex.rgb, shadow ? tex.a * 0.3 : tex.a);
    }

    float adjusted_dissolve = (dissolve * dissolve * (3. - 2. * dissolve)) * 1.02 - 0.01;

    float t = time * 10.0 + 2003.0;
    vec2 uv_centered = (uv - 0.5) * 2.0;

    vec2 field1 = uv_centered + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field2 = uv_centered + 50.0 * vec2(cos( t / 53.1532),  cos( t / 61.4532));
    vec2 field3 = uv_centered + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0000));

    float field = (1.0 + (
        cos(length(field1) / 19.483) +
        sin(length(field2) / 33.155) * cos(field2.y / 15.73) +
        cos(length(field3) / 27.193) * sin(field3.x / 21.92)
    )) / 2.0;

    float res = 0.5 + 0.5 * cos((adjusted_dissolve / 82.612) + ((field - 0.5) * 3.14));

    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && !shadow &&
        res < adjusted_dissolve + 0.8 * (0.5 - abs(adjusted_dissolve - 0.5)) &&
        res > adjusted_dissolve) {
        
        if (res < adjusted_dissolve + 0.5 * (0.5 - abs(adjusted_dissolve - 0.5))) {
            tex.rgba = burn_colour_1.rgba;
        } else if (burn_colour_2.a > 0.01) {
            tex.rgba = burn_colour_2.rgba;
        }
    }

    float alpha = (res > adjusted_dissolve) ? (shadow ? tex.a * 0.3 : tex.a) : 0.0;
    return vec4(shadow ? vec3(0.,0.,0.) : tex.rgb, alpha);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 tex = Texel(texture, texture_coords);
    vec2 uv = texture_coords;

    if (!shadow && dissolve > 0.01) {
        if (burn_colour_2.a > 0.01) {
            tex.rgb = tex.rgb * (1.0 - 0.6 * dissolve) + 0.6 * burn_colour_2.rgb * dissolve;
        } else if (burn_colour_1.a > 0.01) {
            tex.rgb = tex.rgb * (1.0 - 0.6 * dissolve) + 0.6 * burn_colour_1.rgb * dissolve;
        }
    }

    return dissolve_mask(tex, uv);
}

extern MY_HIGHP_OR_MEDIUMP vec2 mouse_screen_pos;
extern MY_HIGHP_OR_MEDIUMP float hovering;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    if (hovering <= 0.0) {
        return transform_projection * vertex_position;
    }

    float mid_dist = length(vertex_position.xy - 0.5 * love_ScreenSize.xy) / length(love_ScreenSize.xy);
    vec2 mouse_offset = vertex_position.xy - mouse_screen_pos.xy;
    float scale = 0.2 * (-0.03 - 0.3 * max(0.0, 0.3 - mid_dist)) * hovering * dot(mouse_offset, mouse_offset) / (2.0 - mid_dist);

    return transform_projection * vertex_position + vec4(0.0, 0.0, 0.0, scale);
}
#endif
