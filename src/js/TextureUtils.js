/**
 * @author Raoul Harel
 * @license The MIT license (LICENSE.txt)
 * @copyright 2015 Raoul Harel
 * @url https://github.com/rharel/webgl-pathtracer
 */

var TextureUtils = {};

TextureUtils._from_array = function(array) {

  var texture = new THREE.DataTexture(

    new Float32Array(array),
    array.length / 3, 1,
    THREE.RGBFormat, THREE.FloatType,
    THREE.UVMapping,
    THREE.ClampToEdgeWrapping, THREE.ClampToEdgeWrapping,
    THREE.NearestFilter, THREE.NearestFilter
  );

  texture.needsUpdate = true;

  return texture;
};


TextureUtils.from_vec3_array = function(array) {

  var data = array.map(function(v) { return [v.x, v.y, v.z]; });
  data = [].concat.apply([], data);

  return TextureUtils._from_array(data);
};


TextureUtils.from_float_array = function(array) {

  var data = array.map(function(x) { return [x, x, x]; });
  data = [].concat.apply([], data);

  return TextureUtils._from_array(data);
};
