/**
 * @author Raoul Harel
 * @license The MIT license (LICENSE.txt)
 * @copyright 2015 Raoul Harel
 * @url https://github.com/rharel/webgl-pathtracer
 */


if (typeof window !== 'undefined') {

  window.GLPT = {

    Shader: {

      vertex: VERTEX_SHADER_SOURCE,
      fragment: FRAGMENT_SHADER_SOURCE
    },

    Primitive: Primitive,
    Material: Material,
    Light: Light,

    Renderer: Renderer,

    Stratifier: Stratifier
  };
}
