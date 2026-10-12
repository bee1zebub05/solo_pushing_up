#version 460 core
// Vân sáng khúc xạ dưới nước (Thuỷ Tinh): mạng lưới sáng lượn của nhiễu
// Worley động — sáng ở chỗ hai tâm ô gần nhất cách đều (F2 − F1 nhỏ). Hai lớp
// lệch tỉ lệ nhân nhau cho lưới mảnh; sáng gần mặt nước, nhạt xuống sâu.
// Vẽ cộng màu (plus) trong vùng nước.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uStrength; // 0–1

out vec4 fragColor;

vec2 hash2(vec2 p) {
  p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
  return fract(sin(p) * 43758.5453);
}

// Khoảng cách F2 − F1 tới tâm ô; tâm ô lượn tròn theo thời gian.
float cellEdge(vec2 p, float t) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  float d1 = 8.0;
  float d2 = 8.0;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 g = vec2(float(x), float(y));
      vec2 o = hash2(i + g);
      o = 0.5 + 0.42 * sin(t + 6.2831 * o);
      float d = length(g + o - f);
      if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
    }
  }
  return d2 - d1;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  // Tỉ lệ ảnh rộng (vùng nước dài): giữ ô gần tròn.
  vec2 p = vec2(uv.x * 9.0, uv.y * 3.0);
  float t = uTime;
  float e1 = cellEdge(p + vec2(t * 0.15, 0.0), t * 0.9);
  float e2 = cellEdge(p * 1.7 + vec2(-t * 0.1, 3.1), t * 1.1 + 2.0);
  float lines = (1.0 - smoothstep(0.0, 0.16, e1)) * 0.75
              + (1.0 - smoothstep(0.0, 0.12, e2)) * 0.45;
  lines = clamp(lines, 0.0, 1.0);
  // Sáng gần mặt nước, nhạt dần xuống đáy.
  float depth = 1.0 - smoothstep(0.0, 1.0, uv.y);
  float k = lines * (0.25 + 0.75 * depth) * uStrength;
  vec3 c = vec3(0.80, 0.97, 1.00) * k * 0.55;
  fragColor = vec4(c, 0.0);
}
