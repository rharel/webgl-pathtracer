#version 100

/**
 * Path tracing for a pixel.
 *
 * @note
 *   Identifiers with suffix '_' (underscore) are replaced with appropriate
 *   values by an external preprocessing step in Renderer.js
 */

precision mediump float;

// constants //

// scene-object quantities

const int N_RANDOM_SEEDS = N_RANDOM_SEEDS_;
const int N_MATERIAL_LAMBERT = N_MATERIAL_LAMBERT_;
const int N_GEOMETRY_SPHERE = N_GEOMETRY_SPHERE_;
const int N_GEOMETRY_PLANE = N_GEOMETRY_PLANE_;
const int N_LIGHTING_SPHERE = N_LIGHTING_SPHERE_;

// material types

const int MATERIAL_LAMBERT = 0;

// mathematical constants

const float M_INFINITY = 10000.0;
const float M_PI = 3.14159265358;
const float M_2_PI = 6.28318530718;
const float M_EPSILON = 0.001;  // small number

// misc

const vec3 UNIT_Y = vec3(0, 1, 0);

const int MAX_DEPTH = 3;  // max #(ray bounces)

// uniforms //

// global

uniform sampler2D random_seeds;

// pixel sampling

uniform int pixel_sampler_grid_degree;

// camera

uniform vec3 camera_position;
uniform mat4 camera_world_matrix;
uniform mat4 camera_projection_matrix_inverse;

// scene

uniform sampler2D material_lambert_color;

uniform vec3 geometry_plane_position[N_GEOMETRY_PLANE + 1];
uniform vec3 geometry_plane_normal[N_GEOMETRY_PLANE + 1];
uniform int geometry_plane_material_type[N_GEOMETRY_PLANE + 1];
uniform int geometry_plane_material_index[N_GEOMETRY_PLANE + 1];

uniform vec3 geometry_sphere_position[N_GEOMETRY_SPHERE + 1];
uniform float geometry_sphere_radius[N_GEOMETRY_SPHERE + 1];
uniform int geometry_sphere_material_type[N_GEOMETRY_SPHERE + 1];
uniform int geometry_sphere_material_index[N_GEOMETRY_SPHERE + 1];

uniform sampler2D lighting_sphere_position;
uniform sampler2D lighting_sphere_radius;
uniform sampler2D lighting_sphere_color;
uniform sampler2D lighting_sphere_intensity;

// inputs from vertex shader //

varying vec2 vs_pixel;

// structs //

struct SphereLight {

    vec3 position;
    float radius;

    vec3 color;
    float intensity;
};

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

    vec3 normal;

    Material material;
};

// methods //

// texture sampling

vec4 sample_1d(sampler2D sampler, const int i, const int n) {

    float x = (float(i) + 0.5) / float(n);
    return texture2D(sampler, vec2(x, 0.5));
}

SphereLight get_sphere_light(const int i) {

    return SphereLight(

        vec3(sample_1d(

            lighting_sphere_position, i, N_LIGHTING_SPHERE
        )),

        sample_1d(

            lighting_sphere_radius, i, N_LIGHTING_SPHERE
        ).x,

        vec3(sample_1d(

            lighting_sphere_color, i, N_LIGHTING_SPHERE
        )),

        sample_1d(

            lighting_sphere_intensity, i, N_LIGHTING_SPHERE
        ).x
    );
}

// matrix

mat3 rotation_axis_angle(const vec3 axis, const float angle) {

    float x = axis.x;
    float y = axis.y;
    float z = axis.z;

    float c = cos(angle);
    float s = sin(angle);
    float a = 1.0 - c;

    return mat3(

        x * x * a + c,
        y * x * a + z * s,
        z * x * a - y * s,

        x * y * a - z * s,
        y * y * a + c,
        z * y * a + x * s,

        x * z * a + y * s,
        y * z * a - x * s,
        z * z * a + c
    );
}

// random

/**
 * @credit byblacksmith.com
 */
highp float noise(vec2 co)
{
    highp float a = 12.9898;
    highp float b = 78.233;
    highp float c = 43758.5453;
    highp float dt = dot(co.xy ,vec2(a,b));
    highp float sn = mod(dt,3.14);

    return fract(sin(sn) * c);
}

highp float random(const int i) {

    return noise(

        0.5 * (gl_FragCoord.xy + sample_1d(random_seeds, i, N_RANDOM_SEEDS).x)
    );
}

int random_range_i(const int a, const int b, const float r) {

    return a + int(floor(float(b - a) * r));
}

float random_range(const float a, const float b, const float r) {

    return a + (b - a) * r;
}

vec3 random_on_sphere(
    const vec3 center, const float radius,
    const float r1, const float r2) {

    float u = random_range(-1.0, 1.0, r1);
    float theta = random_range(0.0, M_2_PI, r2);

    float c = sqrt(1.0 - u * u);

    return center + radius * vec3(

        c * cos(theta),
        c * sin(theta),
        u
    );
}

vec3 random_on_hemisphere(
    const vec3 center, const float radius, const vec3 normal,
    const float r1, const float r2) {

    float a = M_2_PI * r1;
    float b = sqrt(1.0 - r2 * r2);

    vec3 v = normalize(vec3(cos(a) * b, sin(a) * b, r2));

    // align with hemisphere normal

    vec3 axis = normalize(cross(normal, UNIT_Y));
    float angle = acos(dot(normal, v));

    vec3 d = rotation_axis_angle(axis, angle) * v;

    return center + d * radius;
}

// tracing

/**
 * @brief   Computes the form factor (also known as G) between two points.
 *
 * @param   a      Point A.
 * @param   Na     Surface normal at A.
 * @param   b      Point B.
 * @param   Nb     Surface normal at B.
 *
 * @returns Form factor G between A and B.
 */
float form_factor(
        const vec3 a, const vec3 na,
        const vec3 b, const vec3 nb) {

    vec3 d = b - a;
    vec3 v = normalize(d);

    return (abs(dot(v, na)) * abs(dot(v, nb))) / dot(d, d);
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
 * Tests for ray-sphere intersection.
 */
float intersect_sphere(const Ray ray, const vec3 center, const float radius) {

    vec3 co = ray.origin - center;
    float r2 = radius * radius;

    float co_len2 = dot(co, co);

    if (co_len2 < r2) { return -1.0; }  // origin is inside the sphere

    float a = dot(ray.direction, ray.direction);
    float b = dot(ray.direction, co) * 2.0;
    float c = co_len2 - r2;

    float det = b * b - 4.0 * a * c;

    if (det < 0.0) { return -1.0; }  // no intersection

    float sqrt_det = sqrt(det);
    float t = (-b + sqrt_det) / (2.0 * a);

    if (det == 0.0) { return t; }
    else { return min(t, (-b - sqrt_det) / (2.0 * a)); }
}

/**
 * Casts a ray through all planes in the scene and returns the earliest collision
 * that happens before a given collision.
 */
void raycast_planes(const Ray ray, inout Collision collision) {

    for (int i = 0; i < N_GEOMETRY_PLANE; ++i) {

        vec3 position = geometry_plane_position[i];
        vec3 normal = geometry_plane_normal[i];

        float t = intersect_plane(ray, position, normal);

        if (t >= M_EPSILON && t < collision.t) {

             collision.exists = true;

             collision.t = t;

             collision.normal = normal;

             collision.material = Material(

                geometry_plane_material_type[i],
                geometry_plane_material_index[i]
             );
        }
    }
}

/**
 * Casts a ray through all spheres in the scene and returns the earliest collision
 * that happens before a given collision.
 */
void raycast_spheres(const Ray ray, inout Collision collision) {

    for (int i = 0; i < N_GEOMETRY_SPHERE; ++i) {

        vec3 position = geometry_sphere_position[i];
        float radius = geometry_sphere_radius[i];

        float t = intersect_sphere(ray, position, radius);

        if (t >= M_EPSILON && t < collision.t) {

            collision.exists = true;

            collision.t = t;

            vec3 collision_point = (ray.origin + ray.direction * t);
            collision.normal = normalize(collision_point - position);

            collision.material = Material(

               geometry_sphere_material_type[i],
               geometry_sphere_material_index[i]
            );
        }
    }
}

Collision raycast(const Ray ray, const float min_t) {

    Collision collision;
    collision.exists = false;
    collision.t = min_t;

    raycast_planes(ray, collision);
    raycast_spheres(ray, collision);

    return collision;
}

/**
 * Casts a ray through the scene and returns first collision.
 */
Collision raycast(const Ray ray) {

    return raycast(ray, M_INFINITY);
}

/**
 * Returns true if there is no obstacle blocking rays from A to B.
 */
bool visible(const vec3 a, const vec3 b) {

    vec3 ab = b - a;
    float d = length(ab);
    Collision collision = raycast(Ray(a, normalize(ab)), d - M_EPSILON);

    return !collision.exists;
}

/**
 * Evaluates a lambertian brdf with given albedo.
 */
vec3 brdf_lambert(const vec3 albedo) {

    return albedo / M_PI;
}

/**
 * Bounces a ray off a lambertian surface.
 *
 * @param rsi   Random seed offset.
 */
vec3 bounce_lambert(inout int rsi, out float pdf) {

    float r1 = random(rsi++);
    float r2 = random(rsi++);

    float a = M_2_PI * r1;
    float b = sqrt(1.0 - r2 * r2);

    pdf = 1.0 / M_2_PI;  // uniform sampling

    return normalize(vec3(cos(a) * b, sin(a) * b, r2));
}

/**
 * Estimate direct illumination radiance.
 *
 * @param x         Contact point.
 * @param nx        Normal at contact point.
 * @param material  Material at contact point.
 * @param rsi       Random seed offset.
 */
vec3 illuminate(const vec3 x, const vec3 nx, const Material material, inout int rsi) {

    int light_index = random_range_i(

        0, N_LIGHTING_SPHERE, random(rsi++)
    );

    SphereLight light = get_sphere_light(light_index);

    vec3 y = random_on_sphere(

        light.position, light.radius,
        random(rsi++), random(rsi++)
    );

    if (!visible(x, y)) { return vec3(0, 0, 0); }

    vec3 P;  // BRDF
    float G;  // form factor

    vec3 L = light.color * light.intensity;
    vec3 ny = normalize(y - light.position);

    if (material.type == MATERIAL_LAMBERT) {

        vec3 albedo = vec3(sample_1d(

            material_lambert_color, material.index, N_MATERIAL_LAMBERT
        ));

        P = brdf_lambert(albedo);
        G = form_factor(x, nx, y, ny);
    }

    return P * L * G;
}

/**
 * Traces a ray through the scene.
 *
 * @returns Color.
 */
vec3 trace(Ray ray) {

    int rsi = 0;  // random seed index

    vec3 color = vec3(0, 0, 0);
    float weight = 1.0;

    Collision collision;

    for (int depth = 0; depth < 4; depth++) {

        collision = raycast(ray);

        if (!collision.exists) { break; }

        vec3 collision_point = ray.origin + ray.direction * collision.t;

        // direct lighting //

        color += weight * illuminate(collision_point, collision.normal, collision.material, rsi);

        // bounce ray //

        float pdf;
        vec3 bounce_direction = bounce_lambert(rsi, pdf);  // on unit hemisphere

        if (all(equal(collision.normal, -UNIT_Y))) { bounce_direction.y *= -1.0; }
        else {

            if (!all(equal(collision.normal, UNIT_Y))) {

                vec3 axis = normalize(cross(collision.normal, UNIT_Y));
                float angle = acos(dot(collision.normal, bounce_direction));

                bounce_direction = rotation_axis_angle(axis, angle) * bounce_direction;
            }
        }

        weight *= dot(-ray.direction, collision.normal);

        ray.origin = collision_point;
        ray.direction = normalize(bounce_direction);
    }

    return clamp(color, 0.0, 1.0);
}

/**
 * Traces a ray through a pixel.
 *
 * @returns Color.
 */
vec3 trace_through(const vec2 pixel) {

    // Pixel in camera space
    vec3 p = vec3(camera_projection_matrix_inverse * vec4(pixel, 0, 1));

    // Ray origin in world space
    vec3 o = camera_position;

    // Ray direction in world space
    vec3 D = vec3(camera_world_matrix * vec4(p, 1)) - o;

    // Trace
    return trace(Ray(o, normalize(D)));
}

void main(void) {

    gl_FragColor = vec4(trace_through(vs_pixel), 1);
}
