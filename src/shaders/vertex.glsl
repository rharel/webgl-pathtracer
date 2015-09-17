#version 100


attribute vec3 position;

varying vec2 vs_pixel;


void main (void) {

    vs_pixel = vec2(position.x + 1.0, position.y + 1.0);
    vs_pixel *= 0.5;

    gl_Position = vec4(position.x, position.y, 0, 1);
}
