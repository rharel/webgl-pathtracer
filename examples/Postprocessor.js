/**
 * @author Raoul Harel
 * @license The MIT license (LICENSE.txt)
 * @copyright 2015 Raoul Harel
 * @url https://github.com/rharel/webgl-pathtracer
 */


function Postprocessor(width, height) {

  this._render_target = {

    current: new THREE.WebGLRenderTarget(width, height, {

      type: THREE.FloatType,

      minFilter: THREE.NearestFilter,
      magFilter: THREE.NearestFilter
    }),

    sum_in: new THREE.WebGLRenderTarget(width, height, {

      type: THREE.FloatType,

      minFilter: THREE.NearestFilter,
      magFilter: THREE.NearestFilter
    }),

    sum_out: new THREE.WebGLRenderTarget(width, height, {

      type: THREE.FloatType,

      minFilter: THREE.NearestFilter,
      magFilter: THREE.NearestFilter
    })
  };

  this._operator_add = new THREE.RawShaderMaterial({

    uniforms: {

      a: {type: 't', value: this._render_target.current},
      b: {type: 't', value: this._render_target.sum_in}
    },

    vertexShader: Postprocessor._VERTEX_SHADER,
    fragmentShader: Postprocessor._ADD_FRAGMENT_SHADER,

    side: THREE.DoubleSide
  });

  this._operator_average = new THREE.RawShaderMaterial({

    uniforms: {

      sum: {type: 't', value: this._render_target.sum_out},
      divisor: {type: 'i', value: 1}
    },

    vertexShader: Postprocessor._VERTEX_SHADER,
    fragmentShader: Postprocessor._AVERAGE_FRAGMENT_SHADER,

    side: THREE.DoubleSide
  });

  var quad_vertices = new THREE.Float32Attribute(6 * 3, 3);

  quad_vertices.setXYZ(0, -1, -1, 0);
  quad_vertices.setXYZ(1, -1,  1, 0);
  quad_vertices.setXYZ(2,  1,  1, 0);

  quad_vertices.setXYZ(3,  1,  1, 0);
  quad_vertices.setXYZ(4,  1, -1, 0);
  quad_vertices.setXYZ(5, -1, -1, 0);

  var quad_geometry = new THREE.BufferGeometry();
  quad_geometry.addAttribute('position', quad_vertices);

  this._quad_mesh = new THREE.Mesh(quad_geometry, null);

  this._scene = new THREE.Scene();
  this._scene.add(this._quad_mesh);

  this._divisor = 1;
}


Postprocessor._VERTEX_SHADER = [

  '#version 100',


  'attribute vec3 position;',

  'varying vec2 vs_pixel;',

  'void main(void) {',

  '   vs_pixel = (position.xy + 1.0) * 0.5;',
  '   gl_Position = vec4(position.x, position.y, 0, 1);',
  '}'
].join('\n');

Postprocessor._ADD_FRAGMENT_SHADER = [

  '#version 100',

  'precision highp float;',

  'uniform sampler2D a;',
  'uniform sampler2D b;',

  'varying vec2 vs_pixel;',

  'void main(void) {',

  '   gl_FragColor = texture2D(a, vs_pixel) + texture2D(b, vs_pixel);',
  '}'
].join('\n');

Postprocessor._AVERAGE_FRAGMENT_SHADER = [

  '#version 100',

  'precision highp float;',
  'precision highp int;',

  'uniform sampler2D sum;',
  'uniform int divisor;',

  'varying vec2 vs_pixel;',

  'void main(void) {',

  '  gl_FragColor = texture2D(sum, vs_pixel) / float(divisor);',
  '}'
].join('\n');

Postprocessor._DUMMY_CAMERA = new THREE.PerspectiveCamera();


Postprocessor.prototype = {

  constructor: Postprocessor,

  process: function(renderer) {

    this._operator_add.uniforms.b.value = this._render_target.sum_in;
    this._operator_average.uniforms.sum.value = this._render_target.sum_out;

    this._quad_mesh.material = this._operator_add;

    renderer.render(

      this._scene, Postprocessor._DUMMY_CAMERA,
      this._render_target.sum_out
    );

    this._quad_mesh.material = this._operator_average;

    this._operator_average.uniforms.divisor.value = this._divisor;

    renderer.render(

      this._scene, Postprocessor._DUMMY_CAMERA
    );

    var tmp = this._render_target.sum_in;
    this._render_target.sum_in = this._render_target.sum_out;
    this._render_target.sum_out = tmp;
  },

  get input_render_target() { return this._render_target.current; },

  get divisor() { return this._divisor; },
  set divisor(value) { this._divisor = +value; }
};
