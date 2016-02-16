/**
 * @author Raoul Harel
 * @license The MIT license (LICENSE.txt)
 * @copyright 2015 Raoul Harel
 * @url https://github.com/rharel/webgl-pathtracer
 */

/**
 * The Tracer class is responsible for rendering a scene.
 *
 * @param options Initial options object with the following keys:
 *                resolution - {x:, y:}
 *                pixel_sampler - {stratifier:, <stratifier-dependent-options>:}
 *
 * @note Currently, the only pixel sampler stratifier type Grid. See the documentation for the
 *       Stratifier enumeration for additional information on its parameters.
 *
 * @constructor
 */
function Tracer(options) {

  var default_options = {

    resolution: {x: 100, y: 100},
    pixel_sampler: {

      stratifier: Stratifier.Grid,
      degree: 4
    }
  };

  options = options || default_options;

  this._resolution = options.resolution || default_options.resolution;
  this._pixel_sampler = options.pixel_sampler || default_options.pixel_sampler;

  this._scene = {materials: [], geometry: [], lighting: []};
  this._camera = new THREE.PerspectiveCamera(75, 1, 0.1, 1000);

  this._random_seeds = [];

  this._screen = new Screen();

  this._clear_buffers();
}


Tracer.N_RANDOM_SEEDS = 1000;


Tracer.prototype = {

  constructor: Tracer,

  _clear_buffers: function() {

    this._materials = {

      lambert: { color: [] },
      mirror: { gloss: [] }
    };
    this._material_index_map = {};

    this._geometry = {

      sphere: {

        position: [],
        radius: [],

        material_type: [],
        material_index: []
      },

      plane: {

        position: [],
        normal: [],

        material_type: [],
        material_index: []
      }
    };

    this._lighting = {

      sphere: {

        position: [],
        radius: [],
        color: [],
        intensity: []
      }
    };
  },

  _process_materials: function(materials) {

    for (var i = 0; i < materials.length; ++i) {

      var material = materials[i];

      if (material.type === Material.Lambert) {

        this._process_material_lambert(material);

        this._material_index_map[i] = {

          type: Material.Lambert,
          index: this._materials.lambert.color.length - 1
        };
      }

      else if (material.type === Material.Mirror) {

        this._process_material_mirror(material);

        this._material_index_map[i] = {

          type: Material.Mirror,
          index: this._materials.mirror.gloss.length - 1
        };
      }
    }
  },
  _process_material_lambert: function(material) {

    var color = material.color;

    this._materials.lambert.color.push(

      new THREE.Vector3(color.r, color.g, color.b)
    );
  },
  _process_material_mirror: function(material) {

    var gloss = typeof material.gloss !== 'undefined' ? material.gloss : 0;

    this._materials.mirror.gloss.push(gloss);
  },

  _process_geometry: function(geometries) {

    var geometry, shape, material;
    var buffer;

    for (var i = 0; i < geometries.length; ++i) {

      geometry = geometries[i];
      shape = geometry.shape;
      material = this._material_index_map[geometry.material_index];

      if (shape.type === Primitive.Sphere) {

        buffer = this._geometry.sphere;
        this._process_geometry_sphere(geometry);
      }

      else if (shape.type === Primitive.Plane) {

        buffer = this._geometry.plane;
        this._process_geometry_plane(geometry);
      }

      buffer.material_type.push(material.type);
      buffer.material_index.push(material.index);
    }
  },
  _process_geometry_sphere: function(geometry) {

    var buffer = this._geometry.sphere;
    var shape = geometry.shape;

    buffer.position.push(

      new THREE.Vector3(

        shape.position.x,
        shape.position.y,
        shape.position.z
      )
    );

    buffer.radius.push(shape.radius);
  },
  _process_geometry_plane: function(geometry) {

    var buffer = this._geometry.plane;
    var shape = geometry.shape;

    buffer.position.push(

      new THREE.Vector3(

        shape.position.x,
        shape.position.y,
        shape.position.z
      )
    );

    buffer.normal.push(

      new THREE.Vector3(

        shape.normal.x,
        shape.normal.y,
        shape.normal.z
      ).normalize()
    );
  },

  _process_lighting: function(lights) {

    var light;
    var buffer;

    for (var i = 0; i < lights.length; ++i) {

      light = lights[i];

      if (light.type === Light.Sphere) {

        buffer = this._lighting.sphere;
        this._process_lighting_sphere(light);
      }

      buffer.color.push(

        new THREE.Vector3(light.color.r, light.color.g, light.color.b)
      );
      buffer.intensity.push(light.intensity);
    }
  },
  _process_lighting_sphere: function(light) {

    var buffer = this._lighting.sphere;

    buffer.position.push(

      new THREE.Vector3(

        light.position.x,
        light.position.y,
        light.position.z
      )
    );

    buffer.radius.push(light.radius);
  },

  _process_shader_source: function() {

    this._vertex_shader = VERTEX_SHADER_SOURCE;

    this._fragment_shader =

      FRAGMENT_SHADER_SOURCE

        .replace(/N_RANDOM_SEEDS_/g, Tracer.N_RANDOM_SEEDS)

        .replace(/N_MATERIAL_LAMBERT_/g, this._materials.lambert.color.length.toString())
        .replace(/N_MATERIAL_MIRROR_/g, this._materials.mirror.gloss.length.toString())

        .replace(/N_GEOMETRY_SPHERE_/g, this._geometry.sphere.position.length.toString())
        .replace(/N_GEOMETRY_PLANE_/g, this._geometry.plane.position.length.toString())

        .replace(/N_LIGHTING_SPHERE_/g, this._lighting.sphere.position.length.toString());
  },
  _setup_shader_material: function() {

    this._shader_uniforms = {

      // globals: //

      random_seeds: {

        type: "t",
        value: TextureUtils.from_float_array(this._random_seeds)
      },

      // pixel sampling //

      resolution: {type: "v2", value: this._resolution },
      pixel_sampler_grid_degree: {type: "i", value: this._pixel_sampler.degree || 1},

      // camera //

      camera_position: {type: "v3", value: this._camera.position},
      camera_world_matrix: {type: "m4", value: this._camera.matrixWorld},
      camera_projection_matrix_inverse: {

        type: "m4",
        value: new THREE.Matrix4().getInverse(this._camera.projectionMatrix)
      },

      // scene //

      material_lambert_color: {

        type: "t",
        value: TextureUtils.from_vec3_array(this._materials.lambert.color)
      },
      material_mirror_gloss: {

        type: "t",
        value: TextureUtils.from_float_array(this._materials.mirror.gloss)
      },

      geometry_sphere_position: {type: "v3v", value: this._geometry.sphere.position},
      geometry_sphere_radius: {type: "fv1", value: this._geometry.sphere.radius},
      geometry_sphere_material_type: {type: "iv1", value: this._geometry.sphere.material_type},
      geometry_sphere_material_index: {type: "iv1", value: this._geometry.sphere.material_index},

      geometry_plane_position: {type: "v3v", value: this._geometry.plane.position},
      geometry_plane_normal: {type: "v3v", value: this._geometry.plane.normal},
      geometry_plane_material_type: {type: "iv1", value: this._geometry.plane.material_type},
      geometry_plane_material_index: {type: "iv1", value: this._geometry.plane.material_index},

      lighting_sphere_position: {

        type: "t",
        value: TextureUtils.from_vec3_array(this._lighting.sphere.position)
      },
      lighting_sphere_radius: {

        type: "t",
        value: TextureUtils.from_float_array(this._lighting.sphere.radius)
      },
      lighting_sphere_color: {

        type: "t",
        value: TextureUtils.from_vec3_array(this._lighting.sphere.color)
      },
      lighting_sphere_intensity: {

        type: "t",
        value: TextureUtils.from_float_array(this._lighting.sphere.intensity)
      }
    };

    this._shader_material = new THREE.RawShaderMaterial({

      uniforms: this._shader_uniforms,

      vertexShader: this._vertex_shader,
      fragmentShader: this._fragment_shader,

      side: THREE.DoubleSide
    });
  },

  _generate_random_seeds: function() {

    for (var i = 0; i < Tracer.N_RANDOM_SEEDS; ++i) {

      this._random_seeds[i] = Math.random();
    }

    this._shader_uniforms.random_seeds.value = TextureUtils.from_float_array(this._random_seeds);
  },

  update: function() {

    this._clear_buffers();

    this._camera.updateMatrix();
    this._camera.updateMatrixWorld();

    this._process_materials(this._scene.materials);
    this._process_geometry(this._scene.geometry);
    this._process_lighting(this._scene.lighting);

    this._process_shader_source();
    this._setup_shader_material();

    this._screen.shader_material = this._shader_material;
  },

  render: function(renderer, target) {

    this._generate_random_seeds();

    renderer.render(this._screen.scene, this._camera, target);
  },

  get scene() { return this._scene; },
  set scene(scene) {

    this._scene = {

      materials: scene.materials.slice(),
      geometry: scene.geometry.slice(),
      lighting: scene.lighting.slice()
    };
  },

  get camera() { return this._camera; },
  set camera(camera) { this._camera = camera; }
};
