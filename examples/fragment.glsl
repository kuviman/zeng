#version 330 core

uniform vec4 u_color;

out vec3 fragColor;

void main() {
  // gl_FragColor = u_color;
  fragColor = vec3(1.0);
}
