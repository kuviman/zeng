#version 150

in vec2 a_pos;

uniform vec2 u_offset;

void main() {
  gl_Position = vec4(a_pos + u_offset, 0.0, 1.0);
}
