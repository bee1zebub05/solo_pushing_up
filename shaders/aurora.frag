#version 460 core
// Cực quang Bắc Âu (Fafnir): rèm sáng uốn lượn, mép dưới rực, tia dọc nhạt
// dần lên trên; xanh lục ở mép dưới chuyển tím ở ngọn. Vẽ cộng màu (plus).
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

float hash(float n) { return fract(sin(n) * 43758.5453); }

float noise1(float x) {
  float i = floor(x);
  float f = fract(x);
  return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

// Một dải rèm: [base] = độ cao mép dưới (0 trên – 1 dưới), [phase] lệch pha.
vec3 curtain(vec2 uv, float base, float phase, float t) {
  float x = uv.x * 3.0;
  // Mép dưới uốn lượn chậm.
  float edge = base
      + 0.10 * sin(x * 1.3 + t * 0.21 + phase)
      + 0.05 * sin(x * 3.1 - t * 0.37 + phase * 2.0)
      + 0.03 * (noise1(x * 4.0 + t * 0.5) - 0.5);
  float d = edge - uv.y;          // > 0: phía trên mép
  if (d < -0.03) return vec3(0.0);
  // Tia dọc: nhiễu tần cao theo x, trôi ngang, nhấp nháy.
  float rays = noise1(x * 22.0 + t * 0.8 + phase * 7.0) * 0.6
             + noise1(x * 55.0 - t * 1.4) * 0.4;
  rays = pow(rays, 1.6);
  // Mép dưới sắc, sáng; nhạt dần lên trên ~0,35 chiều cao.
  float lower = smoothstep(-0.03, 0.0, d) * exp(-d * 7.0);
  float glow = exp(-d * 2.6) * smoothstep(-0.03, 0.02, d);
  float k = lower * (0.5 + 0.9 * rays) + glow * 0.25 * rays;
  vec3 green = vec3(0.20, 1.00, 0.62);
  vec3 violet = vec3(0.62, 0.38, 1.00);
  vec3 col = mix(green, violet, smoothstep(0.02, 0.28, d));
  return col * k;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float t = uTime;
  vec3 c = curtain(uv, 0.62, 0.0, t) * 0.75 + curtain(uv, 0.82, 2.4, t) * 0.55;
  // Nhịp "thở" chung của cực quang.
  c *= 0.8 + 0.2 * sin(t * 0.6);
  // Mờ dần ở mép trái/phải và đỉnh ảnh.
  c *= smoothstep(0.0, 0.12, uv.x) * smoothstep(1.0, 0.88, uv.x);
  c *= smoothstep(0.0, 0.25, uv.y);
  c = min(c, vec3(1.0));
  fragColor = vec4(c, 0.0);
}
