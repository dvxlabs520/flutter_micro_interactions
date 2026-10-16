import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Kinds of procedural artwork.
enum SceneStyle {
  /// Layered mountain ridges under a gradient sky with a sun.
  mountains,

  /// Soft overlapping color blobs, like a mesh gradient.
  aurora,

  /// Rolling dunes at dusk.
  dunes,

  /// A city skyline at night with lit windows.
  city,

  /// Concentric rings and orbits on a dark field.
  orbits,
}

/// Procedural images for the image based demos. The showcase never
/// downloads or bundles pictures: every image is painted at runtime with
/// [ui.PictureRecorder] and cached by Flutter's image cache like any other
/// [ImageProvider].
///
/// ```dart
/// Image(image: GeneratedImage(style: SceneStyle.mountains, seed: 3))
/// ```
@immutable
class GeneratedImage extends ImageProvider<GeneratedImage> {
  const GeneratedImage({
    required this.style,
    this.seed = 0,
    this.width = 960,
    this.height = 640,
  });

  final SceneStyle style;
  final int seed;
  final int width;
  final int height;

  /// A few ready made scenes, handy for carousels and galleries.
  static const List<GeneratedImage> gallery = [
    GeneratedImage(style: SceneStyle.mountains, seed: 1),
    GeneratedImage(style: SceneStyle.aurora, seed: 2),
    GeneratedImage(style: SceneStyle.dunes, seed: 3),
    GeneratedImage(style: SceneStyle.city, seed: 4),
    GeneratedImage(style: SceneStyle.orbits, seed: 5),
    GeneratedImage(style: SceneStyle.mountains, seed: 6),
    GeneratedImage(style: SceneStyle.aurora, seed: 7),
  ];

  @override
  Future<GeneratedImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<GeneratedImage>(this);

  @override
  ImageStreamCompleter loadImage(
    GeneratedImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_render(key));
  }

  static Future<ImageInfo> _render(GeneratedImage key) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Size size = Size(key.width.toDouble(), key.height.toDouble());
    final Canvas canvas = Canvas(recorder, Offset.zero & size);
    paintScene(canvas, size, key.style, key.seed);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(key.width, key.height);
    picture.dispose();
    return ImageInfo(image: image);
  }

  @override
  bool operator ==(Object other) =>
      other is GeneratedImage &&
      other.style == style &&
      other.seed == seed &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(style, seed, width, height);

  @override
  String toString() => 'GeneratedImage(${style.name}, seed: $seed)';
}

/// Paints a scene directly on a canvas. Also usable from a CustomPainter.
void paintScene(Canvas canvas, Size size, SceneStyle style, int seed) {
  final math.Random r = math.Random(seed * 7919 + style.index);
  switch (style) {
    case SceneStyle.mountains:
      _mountains(canvas, size, r);
    case SceneStyle.aurora:
      _aurora(canvas, size, r);
    case SceneStyle.dunes:
      _dunes(canvas, size, r);
    case SceneStyle.city:
      _city(canvas, size, r);
    case SceneStyle.orbits:
      _orbits(canvas, size, r);
  }
  _grain(canvas, size, r);
}

const List<List<Color>> _skies = [
  [Color(0xFF0F1033), Color(0xFF3B2A7A), Color(0xFFE07A8C), Color(0xFFF7C59F)],
  [Color(0xFF071A2E), Color(0xFF14527A), Color(0xFF63B3C9), Color(0xFFD9F0EC)],
  [Color(0xFF1A0E2E), Color(0xFF5B2A86), Color(0xFFE76F51), Color(0xFFF4A261)],
  [Color(0xFF0B132B), Color(0xFF1C2541), Color(0xFF5BC0BE), Color(0xFFBDE4E3)],
];

void _mountains(Canvas canvas, Size s, math.Random r) {
  final List<Color> sky = _skies[r.nextInt(_skies.length)];
  final Rect rect = Offset.zero & s;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        sky,
        const [0.0, 0.45, 0.78, 1.0],
      ),
  );
  final Offset sun = Offset(
    s.width * (0.25 + r.nextDouble() * 0.5),
    s.height * (0.36 + r.nextDouble() * 0.1),
  );
  canvas.drawCircle(
    sun,
    s.height * 0.32,
    Paint()
      ..shader = ui.Gradient.radial(sun, s.height * 0.32, [
        sky[3].withValues(alpha: 0.55),
        sky[3].withValues(alpha: 0.0),
      ]),
  );
  canvas.drawCircle(sun, s.height * 0.07, Paint()..color = sky[3]);
  const int ridges = 5;
  for (int i = 0; i < ridges; i++) {
    final double t = i / (ridges - 1);
    final double base = s.height * (0.5 + t * 0.32);
    final Color color = Color.lerp(
      Color.lerp(sky[1], sky[2], 0.35)!,
      const Color(0xFF07070C),
      0.25 + t * 0.7,
    )!;
    final Path p = Path()..moveTo(0, s.height);
    double x = 0;
    p.lineTo(0, base);
    while (x < s.width) {
      final double step = s.width * (0.06 + r.nextDouble() * 0.1);
      final double peak =
          base - s.height * (0.06 + r.nextDouble() * 0.14) * (1.0 - t * 0.5);
      p.lineTo(x + step / 2, peak);
      x += step;
      p.lineTo(x, base - r.nextDouble() * s.height * 0.03);
    }
    p
      ..lineTo(s.width, s.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }
}

void _aurora(Canvas canvas, Size s, math.Random r) {
  const List<Color> palette = [
    Color(0xFF6E7BFF),
    Color(0xFF38BDF8),
    Color(0xFFF472B6),
    Color(0xFF34D399),
    Color(0xFFA78BFA),
    Color(0xFFF59E0B),
  ];
  canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0A0A14));
  for (int i = 0; i < 6; i++) {
    final Color c = palette[(i + r.nextInt(palette.length)) % palette.length];
    final Offset center = Offset(
      r.nextDouble() * s.width,
      r.nextDouble() * s.height,
    );
    final double radius = s.shortestSide * (0.35 + r.nextDouble() * 0.45);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          c.withValues(alpha: 0.85),
          c.withValues(alpha: 0.0),
        ])
        ..blendMode = BlendMode.plus,
    );
  }
}

void _dunes(Canvas canvas, Size s, math.Random r) {
  final Rect rect = Offset.zero & s;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        const [Color(0xFF2B1B4A), Color(0xFFB4537A), Color(0xFFF2A65A)],
        const [0.0, 0.55, 1.0],
      ),
  );
  for (int i = 0; i < 5; i++) {
    final double t = i / 4;
    final double base = s.height * (0.55 + t * 0.12);
    final Path p = Path()..moveTo(0, s.height);
    p.lineTo(0, base);
    final double phase = r.nextDouble() * math.pi * 2;
    for (double x = 0; x <= s.width; x += 8) {
      final double y =
          base +
          math.sin(x / s.width * math.pi * (1.2 + t) + phase) * s.height * 0.05;
      p.lineTo(x, y);
    }
    p
      ..lineTo(s.width, s.height)
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFE38B5A),
          const Color(0xFF3A1D35),
          t,
        )!,
    );
  }
}

void _city(Canvas canvas, Size s, math.Random r) {
  final Rect rect = Offset.zero & s;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        const [Color(0xFF05060F), Color(0xFF151A3D), Color(0xFF3A2E6E)],
        const [0.0, 0.6, 1.0],
      ),
  );
  final Paint star = Paint()..color = const Color(0x99FFFFFF);
  for (int i = 0; i < 90; i++) {
    canvas.drawCircle(
      Offset(r.nextDouble() * s.width, r.nextDouble() * s.height * 0.55),
      r.nextDouble() * 1.4,
      star,
    );
  }
  for (int layer = 0; layer < 2; layer++) {
    double x = -10;
    final Color body = layer == 0
        ? const Color(0xFF1B1F45)
        : const Color(0xFF0A0B1C);
    while (x < s.width) {
      final double w = s.width * (0.05 + r.nextDouble() * 0.07);
      final double h = s.height * (0.2 + r.nextDouble() * (0.35 - layer * 0.1));
      final Rect b = Rect.fromLTWH(x, s.height - h, w, h);
      canvas.drawRect(b, Paint()..color = body);
      if (layer == 1) {
        final Paint lit = Paint()
          ..color = const Color(0xFFFFD58A).withValues(alpha: 0.85);
        for (double wy = b.top + 10; wy < b.bottom - 8; wy += 14) {
          for (double wx = b.left + 6; wx < b.right - 6; wx += 10) {
            if (r.nextDouble() < 0.28) {
              canvas.drawRect(Rect.fromLTWH(wx, wy, 4, 6), lit);
            }
          }
        }
      }
      x += w + (layer == 0 ? 4 : 2);
    }
  }
}

void _orbits(Canvas canvas, Size s, math.Random r) {
  final Rect rect = Offset.zero & s;
  canvas.drawRect(rect, Paint()..color = const Color(0xFF07070D));
  final Offset c = Offset(s.width * 0.62, s.height * 0.5);
  canvas.drawCircle(
    c,
    s.shortestSide * 0.7,
    Paint()
      ..shader = ui.Gradient.radial(c, s.shortestSide * 0.7, const [
        Color(0x556E7BFF),
        Color(0x00000000),
      ]),
  );
  final Paint ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  for (int i = 1; i <= 6; i++) {
    final double radius = s.shortestSide * 0.08 * i;
    ring.color = Color.lerp(
      const Color(0xFF9AA3FF),
      const Color(0xFF2A2F66),
      i / 6,
    )!.withValues(alpha: 0.8);
    canvas.drawCircle(c, radius, ring);
    final double a = r.nextDouble() * math.pi * 2;
    canvas.drawCircle(
      c + Offset(math.cos(a), math.sin(a)) * radius,
      3 + r.nextDouble() * 4,
      Paint()..color = const Color(0xFFE3E6FF),
    );
  }
  canvas.drawCircle(c, s.shortestSide * 0.045, Paint()..color = _sun);
}

const Color _sun = Color(0xFFFFE3A3);

void _grain(Canvas canvas, Size s, math.Random r) {
  final Paint p = Paint()..color = const Color(0x0DFFFFFF);
  final int count = (s.width * s.height / 900).round();
  for (int i = 0; i < count; i++) {
    canvas.drawRect(
      Rect.fromLTWH(r.nextDouble() * s.width, r.nextDouble() * s.height, 1, 1),
      p,
    );
  }
}
