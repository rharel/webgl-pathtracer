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
const int N_MATERIAL_MIRROR = N_MATERIAL_MIRROR_;

const int N_GEOMETRY_SPHERE = N_GEOMETRY_SPHERE_;
const int N_GEOMETRY_PLANE = N_GEOMETRY_PLANE_;

const int N_LIGHTING_SPHERE = N_LIGHTING_SPHERE_;

// material types

const int MATERIAL_LAMBERT = 0;
const int MATERIAL_MIRROR = 1;

// mathematical constants

const float M_INFINITY = 10000.0;
const float M_PI = 3.14159265358;
const float M_2_PI = 6.28318530718;
const float M_EPSILON = 0.001;  // small number

// misc

const vec3 UNIT_Y = vec3(0, 1, 0);

const int MAX_DEPTH = 10;  // max #(ray bounces)

// uniforms //

// global

uniform sampler2D random_seeds;

// pixel sampling

uniform vec2 resolution;
uniform int pixel_sampler_grid_degree;

// camera

uniform vec3 camera_position;
uniform mat4 camera_world_matrix;
uniform mat4 camera_projection_matrix_inverse;

// scene

uniform sampler2D material_lambert_color;
uniform sampler2D material_mirror_gloss;

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

    // lambert
    vec3 albedo;

    // mirror
    float gloss;
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

vec3 sample_vec3(sampler2D sampler, const int i, const int n) {

    float x = (float(i) + 0.5) / float(n);
    return vec3(texture2D(sampler, vec2(x, 0.5)));
}

float sample_float(sampler2D sampler, const int i, const int n) {

    return sample_vec3(sampler, i, n).x;
}

//float sample_float(sampler2D sampler, const int i, const int n) {
//
//    float x = (floor(0.25 * float(i)) + 0.5) / (0.25 * float(n));
//    vec4 batch = texture2D(sampler, vec2(x, 0.5));
//    int j = int(mod(float(i), 4.0));
//
//    if (j == 0) { return batch.r; }
//    else if (j == 1) { return batch.g; }
//    else if (j == 2) { return batch.b; }
//    else { return batch.a; }
//}

SphereLight get_sphere_light(const int i) {

    return SphereLight(

        sample_vec3(

            lighting_sphere_position, i, N_LIGHTING_SPHERE
        ),

        sample_float(

            lighting_sphere_radius, i, N_LIGHTING_SPHERE
        ),

        sample_vec3(

            lighting_sphere_color, i, N_LIGHTING_SPHERE
        ),

        sample_float(

            lighting_sphere_intensity, i, N_LIGHTING_SPHERE
        )
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
    highp float dt = dot(co.xy ,vec2(a, b));
    highp float sn = mod(dt, 3.14);

    return fract(sin(sn) * c);
}

vec2 uv;
int rsi = 0;

highp float random() {

    rsi += 1;

    return noise(

        uv.xy + sample_float(random_seeds, rsi, N_RANDOM_SEEDS)
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

            collision.material.type = geometry_plane_material_type[i];
            collision.material.index = geometry_plane_material_index[i];
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

            collision.material.type = geometry_sphere_material_type[i];
            collision.material.index = geometry_sphere_material_index[i];
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
 * Evaluates materials brdf given ray incoming direction and surface normal.
 */
vec3 brdf(const Material material, const vec3 n, const vec3 wi, const vec3 wo) {

    if (material.type == MATERIAL_LAMBERT) {

        return material.albedo / M_PI;
    }

    else if (material.type == MATERIAL_MIRROR) {

        if (all(equal(reflect(-wi, n), wo))) { return vec3(1, 1, 1); }
        else { return vec3(0, 0, 0); }
    }

    return vec3(0, 0, 0);
}

/**
 * Fills in properties of the Material struct based on the common-to-all
 * 'type' and 'index' material identifiers.
 */
void evaluate_material(inout Material material) {

    if (material.type == MATERIAL_LAMBERT) {

        material.albedo = sample_vec3(

            material_lambert_color, material.index, N_MATERIAL_LAMBERT
        );
    }

    else if (material.type == MATERIAL_MIRROR) {

        material.albedo = vec3(1, 1, 1);
        material.gloss = sample_float(

            material_mirror_gloss, material.index, N_MATERIAL_MIRROR
        );
    }
}

/**
 * Bounces a ray off a lambertian surface.
 *
 * @param[out] pdf   Probability of chosen direction.
 *
 * @details
 *      This implementation draws from a cosine-weighted distribution.
 */
vec3 bounce_lambert(out float pdf) {

    float r1 = random();
    float r2 = random();

    float a = M_2_PI * r1;
    float b = sqrt(1.0 - r2);

    float z = sqrt(r2);

    pdf = z / M_PI;

    return normalize(vec3(cos(a) * b, sin(a) * b, z));
}

vec3 bounce(const Material material, const vec3 n, const vec3 wi, out float pdf) {

    vec3 wo;

    if (material.type == MATERIAL_LAMBERT) {

        wo = bounce_lambert(pdf);

        if (all(equal(n, -UNIT_Y))) { wo.y *= -1.0; }
        else if (!all(equal(n, UNIT_Y))) {

            vec3 axis = normalize(cross(n, UNIT_Y));
            float angle = acos(dot(n, wo));

            wo = rotation_axis_angle(axis, angle) * wo;
        }
    }

    else if (material.type == MATERIAL_MIRROR) {

        wo = reflect(-wi, n);
        pdf = 1.0;
    }

    return wo;
}

/**
 * Estimate direct illumination radiance.
 *
 * @param x         Contact point.
 * @param nx        Normal at contact point.
 * @param P         Material brdf at contact point.
 */
vec3 illuminate(const vec3 x, const vec3 nx, const Material material, const vec3 wi) {

    int light_index = random_range_i(

        0, N_LIGHTING_SPHERE, random()
    );

    SphereLight light = get_sphere_light(light_index);

    vec3 y = random_on_sphere(

        light.position, light.radius,
        random(), random()
    );

    if (!visible(x, y)) { return vec3(0, 0, 0); }

    vec3 L = light.color * light.intensity;
    vec3 ny = normalize(y - light.position);
    vec3 wo = normalize(y - x);

    vec3 f = brdf(material, nx, wi, wo);
    float G = form_factor(x, nx, y, ny);
    float A = 4.0 * M_PI * light.radius * light.radius;

    return f * L * G * A;
}

/**
 * Traces a ray through the scene.
 *
 * @returns Color.
 */
vec3 trace(Ray ray) {

    vec3 color = vec3(0, 0, 0);
    vec3 weight = vec3(1, 1, 1);

    Collision collision;

    for (int depth = 0; depth >= 0; depth++) {

        if (depth >= MAX_DEPTH) { break; }

        collision = raycast(ray);

        if (!collision.exists) { break; }

        evaluate_material(collision.material);

        vec3 collision_point = ray.origin + ray.direction * collision.t;
        vec3 wi = -ray.direction;
        float cos_theta = dot(-ray.direction, collision.normal);

        // direct lighting //

        color += weight * illuminate(

            collision_point,
            collision.normal,
            collision.material,
            wi
        );

        // russian roulette //

        float alpha = (

            (collision.material.albedo.x +
             collision.material.albedo.y +
             collision.material.albedo.z) / 3.0
        );

        if (random() > alpha) { break; }
        else { weight /= alpha; }

        // bounce ray //

        float pdf;
        vec3 wo = bounce(collision.material, collision.normal, wi, pdf);

        vec3 f = brdf(collision.material, collision.normal, wi, wo);
        weight *= f * cos_theta / pdf;

        ray.origin = collision_point;
        ray.direction = wo;
    }

    return clamp(color, 0.0, 1.0);
}

/**
 * Traces a ray through a pixel.
 *
 * @param pixel     Pixel in projection space (x, y) e [-1, 1]
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

    uv = (vs_pixel + 1.0) * 0.5;
    rsi = 0;

    float degree = float(pixel_sampler_grid_degree);

    vec2 pixel_size = 2.0 / resolution;
    vec2 cell_size = pixel_size / float(degree);
    vec2 cell_index = vec2(0, 0);

    vec2 origin = vs_pixel - 0.5 * pixel_size;
    vec3 sum = vec3(0, 0, 0);

    cell_index.x = 0.5;

    for (int i = 0; i >= 0; ++i) {

        if (cell_index.x >= degree) { break; }

        cell_index.y = 0.5;

        for (int j = 0; j >= 0; ++j) {

            if (cell_index.y >= degree) { break; }

            sum += trace_through(origin + cell_index * cell_size);

            cell_index.y += 1.0;
        }

        cell_index.x += 1.0;
    }

    gl_FragColor = vec4(sum / (degree * degree), 1);
}
