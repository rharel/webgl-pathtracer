var VERTEX_SHADER_SOURCE = "" +
  "#version 100\n" +
  "\n" +
  "\n" +
  "attribute vec3 position;\n" +
  "\n" +
  "varying vec2 pixel;\n" +
  "\n" +
  "\n" +
  "void main (void) {\n" +
  "\n" +
  "    pixel = vec2(position.x + 1.0, position.y + 1.0);\n" +
  "    pixel *= 0.5;\n" +
  "\n" +
  "    gl_Position = vec4(position.x, position.y, 0, 1);\n" +
  "}\n" +
  "\n";