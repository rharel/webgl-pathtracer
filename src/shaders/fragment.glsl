#version 100

/**
 * Path tracing for a pixel.
 *
 * @note
 *   Identifiers with prefix '_' (underscore) are replaced with appropriate
 *   values by an external preprocessing step in Renderer.js
 */

precision mediump float;


// pixel sampling

uniform int pixel_sampler_grid_degree;

// camera

uniform vec3 camera_position;
uniform mat4 camera_view_matrix;
uniform mat4 camera_world_matrix;
uniform float camera_aspect;
uniform float camera_fov;
uniform float camera_near;

// scene

uniform sampler2D material_lambert_color;

uniform vec3 geometry_plane_position[_N_GEOMETRY_PLANE];
uniform vec3 geometry_plane_normal[_N_GEOMETRY_PLANE];
uniform int geometry_plane_material_type[_N_GEOMETRY_PLANE];
uniform int geometry_plane_material_index[_N_GEOMETRY_PLANE];

uniform vec3 lighting_sphere_position[_N_LIGHTING_SPHERE];
uniform float lighting_sphere_radius[_N_LIGHTING_SPHERE];
uniform vec3 lighting_sphere_color[_N_LIGHTING_SPHERE];

// inputs from vertex shader

varying vec2 vs_pixel;

// constants

const int N_MATERIAL_LAMBERT = _N_MATERIAL_LAMBERT;
const int N_GEOMETRY_PLANE = _N_GEOMETRY_PLANE;

const int MATERIAL_LAMBERT = 0;

const float INFINITY = 10000.0;

const vec3 HORIZON_COLOR = vec3(1, 1, 1);

// structs

struct Material {

    int type;
    int index;
};

struct Ray {

    vec3 origin;
    vec3 direction;
};

struct Collision {

    bool exists;

    float t;

    vec3 position;
    vec3 normal;

    Material material;
};

// methods

vec4 sample_texture_array(sampler2D sampler, const int i, const int n) {

    float x = (float(i) + 0.5) / float(n);
    return texture2D(sampler, vec2(x, 0.5));
}

/**
 * Projects a pixel onto the camera's near plane.
 */
vec3 on_near_plane(const vec2 pixel) {

    float h = tan(0.5 * camera_fov) * camera_near * 2.0;
    float w = camera_aspect * h;

    float top = -0.5 * h;
    float left = -0.5 * w;

    return vec3(

        left + w * pixel.x,
        top + h * pixel.y,
        -camera_near
    );
}


/**
 * Tests for ray-plane intersection.
 */
float intersect_plane(const Ray ray, const vec3 position, const vec3 normal) {

    float dot_nd = dot(normal, ray.direction);

    if (dot_nd >= 0.0) { return -1.0; }
    else { return  dot(-1.0 * normal, ray.origin - position) / dot_nd; }
}

/**
 * Casts a ray through all planes in the scene and returns the earliest collision
 * that happens before a given minimum time.
 */
Collision raycast_planes(const Ray ray, const float min_t) {

    Collision collision;
    collision.exists = false;
    collision.t = min_t;

    for (int i = 0; i < N_GEOMETRY_PLANE; ++i) {

        vec3 position = geometry_plane_position[i];
        vec3 normal = geometry_plane_normal[i];

        float t = intersect_plane(ray, position, normal);

        if (t >= 0.0 && t < collision.t) {

             collision.exists = true;

             collision.t = t;

             collision.position = position;
             collision.normal = normal;

             collision.material = Material(

                geometry_plane_material_type[i],
                geometry_plane_material_index[i]
             );
        }
    }

    return collision;
}

/**
 * Casts a ray through the scene and returns first collision.
 */
Collision raycast(const Ray ray) {

    return raycast_planes(ray, INFINITY);
}

/**
 * Traces a ray through the scene.
 *
 * @returns Color.
 */
vec3 trace(Ray ray) {

    Collision collision = raycast(ray);

    if (collision.exists) {

        int type = collision.material.type;
        int i = collision.material.index;

        if (type == MATERIAL_LAMBERT) {

            vec3 color = vec3(sample_texture_array(

                material_lambert_color, i, N_MATERIAL_LAMBERT
            ));

            return color;
        }
    }

    return HORIZON_COLOR;
}

/**
 * Traces a ray through a pixel.
 *
 * @returns Color.
 */
vec3 trace_through(const vec2 pixel) {

    // Pixel in camera space
    vec3 p = on_near_plane(pixel);

    // Ray origin in world space
    vec3 o = camera_position; //vec3(camera_view_matrix * vec4(0, 0, 0, 1));

    // Ray direction in world space
    vec3 D = vec3(camera_world_matrix * vec4(p, 1)) - o;

    // Trace
    return trace(Ray(o, normalize(D)));
}

void main(void) {

    //gl_FragColor = vec4(vs_pixel.x, vs_pixel.y, 0, 1);
//    gl_FragColor = sample_texture_array(
//        material_lambert_color,
//        int(floor(vs_pixel.x * float(N_MATERIAL_LAMBERT))), N_MATERIAL_LAMBERT);
    //gl_FragColor = vec4(0, 1, 0, 1);
    gl_FragColor = vec4(trace_through(vs_pixel), 1);
}
