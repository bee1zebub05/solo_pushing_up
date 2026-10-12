#version 460 core
// Sương Trì Trệ: màn sương tím xám trôi sát mặt đất, có lọn bốc lên.
// Vẽ vào ảnh nhỏ (lib/art/stage_shaders.dart) rồi phóng lên sân khấu.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;     // kích thước ảnh đích (điểm ảnh)
uniform float uTime;    // giây
uniform float uDensity; // 0 = tan hết, 1 = dày nhất
uniform vec4 uColor;    // màu sương (rgb), a = độ đậm tối đa

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
             mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  // Toạ độ nhiễu theo tỉ lệ sân khấu 400×260, trôi chậm sang trái.
  vec2 p = vec2(uv.x * 4.0, uv.y * 2.6);
  float t = uTime;
  // Uốn miền (domain warp) cho lọn sương cuộn thay vì mây đều.
  vec2 q = vec2(fbm(p + vec2(t * 0.05, 0.0)), fbm(p + vec2(5.2, 1.3 - t * 0.04)));
  float n = fbm(p + 1.6 * q + vec2(t * 0.12, 0.0));

  // Dày sát đất (dưới), mỏng dần lên trên; mật độ cao thì sương dâng cao hơn.
  float top = mix(0.78, 0.42, uDensity);
  float band = smoothstep(top, 1.0, uv.y);
  // Lọn bốc lên: nhiễu cao vượt khỏi dải.
  float wisp = smoothstep(0.55, 0.85, n) * smoothstep(top - 0.25, top + 0.1, uv.y);
  float m = clamp(band * (0.35 + 0.9 * n) + wisp * 0.5, 0.0, 1.0);
  m *= uDensity;

  float a = m * uColor.a;
  // Màu nhân alpha (premultiplied); lõi sương hơi sáng hơn mép.
  vec3 c = uColor.rgb * (0.85 + 0.3 * n);
  fragColor = vec4(c * a, a);
}
