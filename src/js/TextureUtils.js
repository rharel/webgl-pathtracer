/**
 * @author Raoul Harel
 * @license The MIT license (LICENSE.txt)
 * @copyright 2015 Raoul Harel
 * @url https://github.com/rharel/webgl-pathtracer
 */

var TextureUtils = {};

TextureUtils.texture_1d = function(pixels) {

  var data = [];

  pixels.forEach(function(v) {

    data.push(v.x * 255, v.y * 255, v.z * 255);
  });

  var texture = new THREE.DataTexture(

    new Uint8Array(data),
    pixels.length, 1,
    THREE.RGBFormat, THREE.UnsignedByteType,
    THREE.UVMapping,
    THREE.ClampToEdgeWrapping, THREE.ClampToEdgeWrapping,
    THREE.NearestFilter, THREE.NearestFilter
  );

  texture.needsUpdate = true;

  return texture;
};
