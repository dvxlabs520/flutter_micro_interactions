// Morph transition between two images for MorphSlider.
//
// The outgoing image (uFrom) is pushed and warped by a flowing displacement
// field while it dissolves into the incoming image (uTo), which un-warps into
// place. Three effects share the same uniforms:
//   0 = melt   : domain-warped gradient noise, liquid displacement
//   1 = ripple : radial waves travelling out from uOrigin
//   2 = swirl  : vortex twist around uOrigin
//
// Written for Flutter's shader compiler (impellerc): only float, vec2 and
// sampler2D uniforms, no dynamic loops, no sampler arrays.

#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;       // Logical size of the painted rect.
uniform float uProgress;  // 0 = only uFrom, 1 = only uTo.
uniform float uIntensity; // 0..1 strength of the distortion.
uniform float uEffect;    // 0 melt, 1 ripple, 2 swirl.
uniform vec2 uDirection;  // Unit vector the content travels in.
uniform vec2 uOrigin;     // Effect origin, normalized 0..1.
uniform float uTime;      // Seconds; animates the flow field.
uniform vec2 uFromSize;   // Pixel size of uFrom.
uniform vec2 uToSize;     // Pixel size of uTo.

uniform sampler2D uFrom;
uniform sampler2D uTo;

out vec4 fragColor;

const float PI = 3.14159265;
const float TAU = 6.28318531;

// ---------------------------------------------------------------------------
// Noise
// ---------------------------------------------------------------------------

float hash21(vec2 p) {
  p = fract(p * vec2(0.3183099, 0.3678794)) + 0.1;
  p += dot(p, p.yx + 19.19);
  return fract(p.x * p.y * 95.4337);
}

vec2 gradientAt(vec2 cell) {
  float a = hash21(cell) * TAU;
  return vec2(cos(a), sin(a));
}

// Gradient noise with quintic interpolation, roughly in [-0.7, 0.7].
float gnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = p - i;
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float a = dot(gradientAt(i), f);
  float b = dot(gradientAt(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
  float c = dot(gradientAt(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
  float d = dot(gradientAt(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Four octaves, unrolled. Each octave is rotated to hide grid alignment.
float fbm(vec2 p) {
  const mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
  float v = 0.5 * gnoise(p);
  p = m * p + vec2(3.1, 1.7);
  v += 0.25 * gnoise(p);
  p = m * p + vec2(-2.3, 4.9);
  v += 0.125 * gnoise(p);
  p = m * p + vec2(5.3, -0.7);
  v += 0.0625 * gnoise(p);
  return v;
}

// ---------------------------------------------------------------------------
// Sampling helpers
// ---------------------------------------------------------------------------

// Maps a widget uv (0..1) into image uv so the image covers the rect without
// stretching (BoxFit.cover, centered).
vec2 coverUv(vec2 uv, vec2 imageSize) {
  vec2 img = max(imageSize, vec2(1.0));
  float s = max(uSize.x / img.x, uSize.y / img.y);
  vec2 scaled = img * s;
  return (uv * uSize - (uSize - scaled) * 0.5) / scaled;
}

// Mirrored repeat keeps displaced lookups inside the image without streaks.
vec2 mirrorUv(vec2 uv) {
  return 1.0 - abs(1.0 - mod(uv, 2.0));
}

vec4 sampleFrom(vec2 uv) {
  return texture(uFrom, mirrorUv(coverUv(uv, uFromSize)));
}

vec4 sampleTo(vec2 uv) {
  return texture(uTo, mirrorUv(coverUv(uv, uToSize)));
}

// Samples with a small chromatic split along [shift] (in uv units).
vec4 sampleFromSplit(vec2 uv, vec2 shift) {
  vec4 c = sampleFrom(uv);
  c.r = sampleFrom(uv + shift).r;
  c.b = sampleFrom(uv - shift).b;
  return c;
}

vec4 sampleToSplit(vec2 uv, vec2 shift) {
  vec4 c = sampleTo(uv);
  c.r = sampleTo(uv + shift).r;
  c.b = sampleTo(uv - shift).b;
  return c;
}

vec2 rotate(vec2 v, float a) {
  float c = cos(a);
  float s = sin(a);
  return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Soft threshold that reveals [field] (0..1, high first) as [p] goes 0..1.
float reveal(float field, float p, float softness) {
  float edge = 1.0 - p * (1.0 + softness);
  return smoothstep(edge, edge + softness, field);
}

// ---------------------------------------------------------------------------
// Effects
// ---------------------------------------------------------------------------

// Two smooth octaves for large, liquid-looking displacement.
float smoothNoise(vec2 p) {
  return 0.66 * gnoise(p) + 0.34 * gnoise(p * 2.03 + vec2(7.1, 3.3));
}

vec4 melt(vec2 uv, vec2 aspect, float p, float k) {
  vec2 a = uv * aspect;
  float t = uTime * 0.3;

  // Domain-warped flow: smooth noise displaced by smooth noise reads as a
  // slow liquid rather than smoke.
  vec2 q = vec2(
    smoothNoise(a * 1.3 + vec2(0.0, t)),
    smoothNoise(a * 1.3 + vec2(5.2, 1.3) - vec2(t, 0.0))
  );
  vec2 flow = vec2(
    smoothNoise(a * 1.4 + 1.5 * q + vec2(1.7, 9.2) + 0.4 * t),
    smoothNoise(a * 1.4 + 1.5 * q + vec2(8.3, 2.8) - 0.4 * t)
  );

  // Reveal order: the side the new image enters from goes first, broken up
  // by the flow and a little fine detail so the front is an organic line.
  vec2 dir = uDirection;
  float lead = dot(uv - 0.5, -dir) + 0.5;
  float detail = fbm(a * 4.0 + 2.0 * flow + vec2(t * 0.5, 0.0));
  float field = clamp(
    lead * 0.68 + (q.x + flow.y) * 0.4 + detail * 0.14 + 0.16, 0.0, 1.0);
  float m = reveal(field, p, 0.08);

  // Pixels are pushed hardest while the front sweeps over them, so the old
  // image smears away along the direction and the new one pours in behind.
  float outAmt = 0.55 * smoothstep(0.0, 1.0, p) + 0.6 * m;
  float inAmt = 0.55 * smoothstep(0.0, 1.0, 1.0 - p) + 0.6 * (1.0 - m);
  vec2 push = dir * 0.4;
  vec2 swirlFlow = flow * 0.6;
  vec2 fromUv = uv - (push + swirlFlow) * k * outAmt / aspect;
  // The incoming image follows the smoother first warp level so it settles
  // calmly instead of churning.
  vec2 toUv = uv + (push - q * 0.6) * k * 0.85 * inAmt / aspect;

  // Chromatic split, strongest on the melting front.
  float front = m * (1.0 - m) * 4.0;
  float split = 0.012 * k * sin(PI * p) * (0.15 + 0.85 * front);
  vec2 shift = normalize(flow + dir * 0.3 + vec2(1e-4)) * split / aspect;
  vec4 from = sampleFromSplit(fromUv, shift);
  vec4 to = sampleToSplit(toUv, -shift);

  vec4 color = mix(from, to, m);

  // A faint sheen rides on the front.
  color.rgb += front * front * 0.1 * k * color.a;
  return color;
}

vec4 ripple(vec2 uv, vec2 aspect, float p, float k) {
  vec2 d = (uv - uOrigin) * aspect;
  float dist = length(d);
  vec2 n = d / max(dist, 1e-4);

  vec2 far = max(uOrigin, 1.0 - uOrigin) * aspect;
  float maxDist = length(far);
  float radius = p * (maxDist + 0.3) - 0.1;
  float x = dist - radius;

  // Rings: a tight crest ahead of the front and decaying rings behind it.
  float ahead = exp(-x * x * 90.0);
  float behind = exp(min(x, 0.0) * 5.0) * step(x, 0.0);
  float rings = max(ahead, behind);
  float wave = sin(x * 52.0 - p * 6.0);
  float env = sin(PI * p);
  float amp = rings * env * k;
  vec2 offset = n * wave * amp * 0.03 / aspect;

  // The new image starts slightly enlarged around the origin and settles.
  float zoomIn = 1.0 - 0.14 * k * (1.0 - p);
  vec2 toUv = uOrigin + (uv - uOrigin) * zoomIn + offset;
  float zoomOut = 1.0 + 0.08 * k * p;
  vec2 fromUv = uOrigin + (uv - uOrigin) / zoomOut + offset * 1.4;

  float edge = x + wave * 0.012 * k + fbm(d * 6.0) * 0.03;
  float m = smoothstep(0.012, -0.012, edge);
  vec2 shift = n * 0.005 * rings * env * k / aspect;
  vec4 from = sampleFromSplit(fromUv, shift);
  vec4 to = sampleToSplit(toUv, shift);
  vec4 color = mix(from, to, m);
  // Light catches the crests like on water.
  float crest = pow(max(wave, 0.0), 3.0);
  color.rgb += crest * rings * env * 0.1 * k * color.a;
  color.rgb -= pow(max(-wave, 0.0), 3.0) * rings * env * 0.06 * k * color.a;
  return color;
}

vec4 swirl(vec2 uv, vec2 aspect, float p, float k) {
  vec2 d = (uv - uOrigin) * aspect;
  float dist = length(d);
  vec2 far = max(uOrigin, 1.0 - uOrigin) * aspect;
  float maxDist = length(far);
  float r = dist / maxDist;

  float falloff = 1.0 - smoothstep(0.0, 1.5, r);
  falloff = falloff * sqrt(falloff);
  float twist = 6.0 * k * falloff;

  // Outgoing image winds up and is pulled inward; incoming image unwinds.
  float pin = smoothstep(0.0, 1.0, p);
  vec2 fromD = rotate(d, twist * pin) * (1.0 + 0.45 * k * pin * falloff);
  vec2 toD = rotate(d, -twist * (1.0 - pin)) *
      (1.0 - 0.3 * k * (1.0 - pin) * falloff);
  vec2 fromUv = uOrigin + fromD / aspect;
  vec2 toUv = uOrigin + toD / aspect;

  // Spiral arms reveal the new image from the center outwards.
  float angle = atan(d.y, d.x);
  float spiral = sin(angle * 3.0 + r * 10.0 - p * 8.0) * 0.07;
  float field = clamp(1.0 - r * 0.9 + spiral + fbm(d * 3.0) * 0.18, 0.0, 1.0);
  float m = reveal(field, p, 0.045);

  vec4 from = sampleFrom(fromUv);
  vec4 to = sampleTo(toUv);
  vec4 color = mix(from, to, m);
  float front = m * (1.0 - m) * 4.0;
  color.rgb += front * 0.06 * k * color.a;
  return color;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 aspect = vec2(uSize.x / uSize.y, 1.0);
  float p = clamp(uProgress, 0.0, 1.0);
  float k = clamp(uIntensity, 0.0, 1.0);

  if (uEffect < 0.5) {
    fragColor = melt(uv, aspect, p, k);
  } else if (uEffect < 1.5) {
    fragColor = ripple(uv, aspect, p, k);
  } else {
    fragColor = swirl(uv, aspect, p, k);
  }
}
