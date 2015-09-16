#version 100


attribute vec3 position;

varying vec2 pixel;


void main (void) {

    pixel = vec2(position.x + 1.0, position.y + 1.0);
    pixel *= 0.5;

    gl_Position = vec4(position.x, position.y, 0, 1);
}
