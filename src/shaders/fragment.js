var FRAGMENT_SHADER_SOURCE = "" +
  "#version 100\n" +
  "\n" +
  "precision mediump float;\n" +
  "\n" +
  "\n" +
  "varying vec2 pixel;\n" +
  "\n" +
  "\n" +
  "void main(void) {\n" +
  "\n" +
  "    gl_FragColor = vec4(pixel.x, pixel.y, 0, 1);\n" +
  "}\n" +
  "\n";