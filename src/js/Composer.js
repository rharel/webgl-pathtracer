/**
 * @author Raoul Harel
 * @license The MIT license (LICENSE.txt)
 * @copyright 2015 Raoul Harel
 * @url https://github.com/rharel/webgl-pathtracer
 */


function Composer(options) {

  var default_options = {

    resolution: {x: 100, y: 100}
  };
  options = options || default_options;

  this._resolution = options.resolution;

  var rt_options = Composer._RENDER_TARGET_OPTIONS;
  var rt_width = options.resolution.x;
  var rt_height = options.resolution.y;

  this._render_target = {

    current: new THREE.WebGLRenderTarget(rt_width, rt_height, rt_options),

    sum_in:  new THREE.WebGLRenderTarget(rt_width, rt_height, rt_options),
    sum_out:  new THREE.WebGLRenderTarget(rt_width, rt_height, rt_options)
  };

  this._operator = {

    add: new THREE.RawShaderMaterial({

      uniforms: {

        a: {type: 't', value: this._render_target.current},
        b: {type: 't', value: this._render_target.sum_in}
      },

      vertexShader: Composer._VERTEX_SHADER,
      fragmentShader: Composer._OPERATOR_ADD_FRAGMENT_SHADER,

      side: THREE.DoubleSide
    }),

    divide: new THREE.RawShaderMaterial({

      uniforms: {

        dividend: {type: 't', value: this._render_target.sum_out},
        divisor: {type: 'i', value: 1}
      },

      vertexShader: Composer._VERTEX_SHADER,
      fragmentShader: Composer._OPERATOR_DIVIDE_FRAGMENT_SHADER,

      side: THREE.DoubleSide
    })
  };

  this._screen = new Screen();

  this._nPasses = 0;
}


Composer._RENDER_TARGET_OPTIONS = {

  type: THREE.FloatType,

  minFilter: THREE.NearestFilter,
  magFilter: THREE.NearestFilter
};

Composer._VERTEX_SHADER = [

  '#version 100',


  'attribute vec3 position;',

  'varying vec2 vs_pixel;',

  'void main(void) {',

  '   vs_pixel = (position.xy + 1.0) * 0.5;',
  '   gl_Position = vec4(position.x, position.y, 0, 1);',
  '}'
].join('\n');

Composer._OPERATOR_ADD_FRAGMENT_SHADER = [

  '#version 100',

  'precision highp float;',

  'uniform sampler2D a;',
  'uniform sampler2D b;',

  'varying vec2 vs_pixel;',

  'void main(void) {',

  '   gl_FragColor = texture2D(a, vs_pixel) + texture2D(b, vs_pixel);',
  '}'
].join('\n');

Composer._OPERATOR_DIVIDE_FRAGMENT_SHADER = [

  '#version 100',

  'precision highp float;',
  'precision highp int;',

  'uniform sampler2D dividend;',
  'uniform int divisor;',

  'varying vec2 vs_pixel;',

  'void main(void) {',

  '  gl_FragColor = texture2D(dividend, vs_pixel) / float(divisor);',
  '}'
].join('\n');

Composer._DUMMY_CAMERA = new THREE.PerspectiveCamera();


Composer.prototype = {

  constructor: Composer,

  update: function() {

    var w = this._resolution.x;
    var h = this._resolution.y;

    this._render_target.current.setSize(w, h);
    this._render_target.sum_in.setSize(w, h);
    this._render_target.sum_out.setSize(w, h);
  },

  clear: function() {

    this._render_target.sum_in.dispose();
    this._render_target.sum_in = new THREE.WebGLRenderTarget(

      this._resolution.x,
      this._resolution.y
    );

    this._nPasses = 0;
  },

  process: function(renderer) {

    ++ this._nPasses;

    this._operator.add.uniforms.b.value = this._render_target.sum_in;
    this._operator.divide.uniforms.dividend.value = this._render_target.sum_out;
    this._operator.divide.uniforms.divisor.value = this._nPasses;

    this._screen.shader_material = this._operator.add;
    renderer.render(

      this._screen.scene, Composer._DUMMY_CAMERA,
      this._render_target.sum_out
    );

    this._screen.shader_material = this._operator.divide;
    renderer.render(

      this._screen.scene, Composer._DUMMY_CAMERA
    );

    this._swap_sum_targets();
  },

  _swap_sum_targets: function() {

    var tmp = this._render_target.sum_in;
    this._render_target.sum_in = this._render_target.sum_out;
    this._render_target.sum_out = tmp;
  },

  get target() { return this._render_target.current; },
  get nPasses() { return this._nPasses; }
};
