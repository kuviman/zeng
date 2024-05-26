attribute vec2 a_pos;
attribute vec2 a_offset;

uniform vec2 u_offset;

void main() {
  gl_Position = vec4(a_pos + a_offset * 0.1 + u_offset, 0.0, 1.0);
}
