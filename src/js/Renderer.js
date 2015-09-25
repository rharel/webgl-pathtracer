/**
 * @author Raoul Harel
 * @license The MIT license (LICENSE.txt)
 * @copyright 2015 Raoul Harel
 * @url https://github.com/rharel/webgl-pathtracer
 */


function Renderer(options) {

  var default_options = {

    pixel_sampler: {

      stratifier: Stratifier.Grid,
      degree: 4
    }
  };

  options = options || default_options;

  this._canvas = options.canvas || document.createElement('canvas');

  this._3_renderer = new THREE.WebGLRenderer({canvas: this._canvas});
  this._3_scene = new THREE.Scene();

  var vertices = new THREE.Float32Attribute(6 * 3, 3);

  vertices.setXYZ(0, -1, -1, 0);
  vertices.setXYZ(1, -1,  1, 0);
  vertices.setXYZ(2,  1,  1, 0);

  vertices.setXYZ(3,  1,  1, 0);
  vertices.setXYZ(4,  1, -1, 0);
  vertices.setXYZ(5, -1, -1, 0);

  this._3_geometry = new THREE.BufferGeometry();
  this._3_geometry.addAttribute('position', vertices);

  this._3_material = null;
  this._3_mesh = null;

  this._pixel_sampler = options.pixel_sampler || default_options.pixel_sampler;
  this._scene = options.scene || [];
  this._camera = options.camera || new THREE.PerspectiveCamera(

      75, this._canvas.width / this._canvas.height, 0.1, 1000
  );
}


Renderer.N_RANDOM_SEEDS = 100;


Renderer.prototype = {

  constructor: Renderer,

  _reset: function() {

    this._materials = {

      lambert: {

        color: []
      }
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

  _process_materials: function(material_collection) {

    for (var i = 0; i < material_collection.length; ++i) {

      var material = material_collection[i];

      if (material.type === Material.Lambert) {

        var color = material.color;

        this._materials.lambert.color.push(

          new THREE.Vector3(color.r, color.g, color.b)
        );

        this._material_index_map[i] = {

          type: Material.Lambert,
          index: this._materials.lambert.color.length - 1
        };
      }
    }
  },

  _process_geometry: function(geometry_collection) {

    var geometry, shape, material;
    var buffer;

    for (var i = 0; i < geometry_collection.length; ++i) {

      geometry = geometry_collection[i];
      shape = geometry.shape;
      material = this._material_index_map[geometry.material_index];

      if (shape.type === Primitive.Sphere) {

        buffer = this._geometry.sphere;

        buffer.position.push(

          new THREE.Vector3(

            shape.position.x,
            shape.position.y,
            shape.position.z
          )
        );

        buffer.radius.push(shape.radius);
      }

      else if (shape.type === Primitive.Plane) {

        buffer = this._geometry.plane;
        
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
      }

      buffer.material_type.push(material.type);
      buffer.material_index.push(material.index);
    }
  },

  _process_lighting: function(lighting_collection) {

    var light;
    var buffer;

    for (var i = 0; i < lighting_collection.length; ++i) {

      light = lighting_collection[i];

      if (light.type === Light.Sphere) {

        buffer = this._lighting.sphere;

        buffer.position.push(

          new THREE.Vector3(

            light.position.x,
            light.position.y,
            light.position.z
          )
        );

        buffer.radius.push(light.radius);
      }

      buffer.color.push(

        new THREE.Vector3(light.color.r, light.color.g, light.color.b)
      );

      buffer.intensity.push(light.intensity);
    }
  },

  _process_shader_source: function() {

    this._vertex_shader = VERTEX_SHADER_SOURCE;

    this._fragment_shader =

      FRAGMENT_SHADER_SOURCE
        .replace(/N_RANDOM_SEEDS_/g, Renderer.N_RANDOM_SEEDS)
        .replace(/N_MATERIAL_LAMBERT_/g, this._materials.lambert.color.length.toString())
        .replace(/N_GEOMETRY_SPHERE_/g, this._geometry.sphere.position.length.toString())
        .replace(/N_GEOMETRY_PLANE_/g, this._geometry.plane.position.length.toString())
        .replace(/N_LIGHTING_SPHERE_/g, this._lighting.sphere.position.length.toString());
  },

  _setup_shader_material: function() {

    var random = [];
    for (var i = 0; i < Renderer.N_RANDOM_SEEDS; ++i) {

      random.push(Math.random());
    }

    var uniforms = {

      // globals: //

      random_seeds: {

        type: "t",
        value: TextureUtils.from_float_array(random)
      },

      // pixel sampling //

      pixel_sampler_grid_degree: {type: "i", value: this._pixel_sampler.degree || 1},

      // camera //

      camera_position: {type: "v3", value: this._camera.position},
      camera_world_matrix: {type: "m4", value: this._camera.matrixWorld},
      camera_projection_matrix_inverse: {

        type: "m4",
        value: new THREE.Matrix4().getInverse(this._camera.projectionMatrix)
      },
      camera_aspect: {type: "f", value: this._camera.aspect},
      camera_fov: {type: "f", value: this._camera.fov},
      camera_near: {type: "f", value: this._camera.near},

      // scene //

      material_lambert_color: {

        type: "t",
        value: TextureUtils.from_vec3_array(this._materials.lambert.color)
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

    this._3_material = new THREE.RawShaderMaterial({

      uniforms: uniforms,

      vertexShader: this._vertex_shader,
      fragmentShader: this._fragment_shader,

      side: THREE.DoubleSide
    });

    this._3_scene.remove(this._3_mesh);
    this._3_mesh = new THREE.Mesh(this._3_geometry, this._3_material);
    this._3_scene.add(this._3_mesh);
  },

  update: function() {

    this._reset();

    this._camera.updateMatrix();
    this._camera.updateMatrixWorld();

    this._process_materials(this._scene.materials);
    this._process_geometry(this._scene.geometry);
    this._process_lighting(this._scene.lighting);

    this._process_shader_source();
    this._setup_shader_material();
  },

  render: function() {

    this._3_renderer.render(this._3_scene, this._camera);
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
  set camera(camera) { this._camera = camera; },

  get canvas() { return this._canvas; }
};
