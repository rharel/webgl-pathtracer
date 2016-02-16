/**
 * @author Raoul Harel
 * @license The MIT license (LICENSE.txt)
 * @copyright 2015 Raoul Harel
 * @url https://github.com/rharel/webgl-pathtracer
 */


function Screen() {

  var position_attribute = new THREE.Float32Attribute(6 * 3, 3);

  Screen._TRIANGLE_VERTICES.forEach(function(vertex, i) {

    position_attribute.setXYZ(i, vertex.x, vertex.y, 0);
  });

  var geometry = new THREE.BufferGeometry();
  geometry.addAttribute('position', position_attribute);

  this._mesh = new THREE.Mesh(geometry, null);

  this._scene = new THREE.Scene();
  this._scene.add(this._mesh);
}


Screen._TRIANGLE_VERTICES = [

  {x: -1, y: -1},
  {x: -1, y:  1},
  {x:  1, y:  1},

  {x:  1, y:  1},
  {x:  1, y: -1},
  {x: -1, y: -1}
];


Screen.prototype = {

  constructor: Screen,

  get shader_material() { return this._mesh.material; },
  set shader_material(shader_material) { this._mesh.material = shader_material; },

  get scene() { return this._scene; }
};
