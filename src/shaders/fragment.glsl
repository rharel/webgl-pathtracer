#version 100

precision mediump float;


varying vec2 pixel;


void main(void) {

    gl_FragColor = vec4(pixel.x, pixel.y, 0, 1);
}
