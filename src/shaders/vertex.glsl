#version 100


attribute vec3 position;

varying vec2 vs_pixel;


void main (void) {

    vs_pixel = vec2(position.x, position.y);

    gl_Position = vec4(position.x, position.y, 0, 1);
}
