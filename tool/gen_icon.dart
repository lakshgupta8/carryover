// Generates the launcher icon PNGs without any image dependency.
//
//   dart run tool/gen_icon.dart
//   dart run flutter_launcher_icons
//
// Writes assets/icon/icon.png (legacy, full-bleed) and
// assets/icon/icon_foreground.png (adaptive foreground with safe-zone padding).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int size = 1024;

void main() {
  File('assets/icon/icon.png').writeAsBytesSync(_png(_render(adaptive: false)));
  File('assets/icon/icon_foreground.png')
      .writeAsBytesSync(_png(_render(adaptive: true)));
  stdout.writeln('Wrote assets/icon/icon.png and assets/icon/icon_foreground.png');
}

/// RGBA pixels. Adaptive foregrounds keep the artwork inside the inner 66%.
Uint8List _render({required bool adaptive}) {
  final px = Uint8List(size * size * 4);
  final center = size / 2;
  final radius = adaptive ? size * 0.33 : size * 0.40;

  // Check mark polyline in disc-normalised coordinates (-1 … 1).
  const a = (-0.42, 0.02);
  const b = (-0.12, 0.34);
  const c = (0.46, -0.30);
  final stroke = radius * 0.17;

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;
      final dx = x + 0.5 - center;
      final dy = y + 0.5 - center;
      final dist = math.sqrt(dx * dx + dy * dy);

      // Background: transparent for the adaptive layer, ivory otherwise.
      double r = 255, g = 252, bl = 245, al = adaptive ? 0 : 255;

      // Disc with a soft gold gradient.
      final discCover = _coverage(radius - dist);
      if (discCover > 0) {
        final t = ((dx + dy) / (radius * 2.2) + 0.5).clamp(0.0, 1.0);
        final gold = _lerp3(const (233, 204, 106), const (212, 175, 55), const (184, 144, 42), t);
        final rim = _coverage(dist - (radius - radius * 0.06));
        final shaded = (
          gold.$1 * (1 - rim * 0.12),
          gold.$2 * (1 - rim * 0.12),
          gold.$3 * (1 - rim * 0.12),
        );
        r = _mix(r, shaded.$1, discCover);
        g = _mix(g, shaded.$2, discCover);
        bl = _mix(bl, shaded.$3, discCover);
        al = math.max(al, discCover * 255);
      }

      // Check mark.
      final nx = dx / radius;
      final ny = dy / radius;
      final d = math.min(_segDist(nx, ny, a, b), _segDist(nx, ny, b, c)) * radius;
      final checkCover = _coverage(stroke / 2 - d) * discCover;
      if (checkCover > 0) {
        r = _mix(r, 255, checkCover);
        g = _mix(g, 255, checkCover);
        bl = _mix(bl, 255, checkCover);
      }

      px[i] = r.round().clamp(0, 255);
      px[i + 1] = g.round().clamp(0, 255);
      px[i + 2] = bl.round().clamp(0, 255);
      px[i + 3] = al.round().clamp(0, 255);
    }
  }
  return px;
}

double _coverage(double signed) => (signed + 0.5).clamp(0.0, 1.0);

double _mix(double from, double to, double t) => from + (to - from) * t;

(double, double, double) _lerp3(
  (int, int, int) c0,
  (int, int, int) c1,
  (int, int, int) c2,
  double t,
) {
  if (t < 0.5) {
    final u = t / 0.5;
    return (_mix(c0.$1.toDouble(), c1.$1.toDouble(), u), _mix(c0.$2.toDouble(), c1.$2.toDouble(), u), _mix(c0.$3.toDouble(), c1.$3.toDouble(), u));
  }
  final u = (t - 0.5) / 0.5;
  return (_mix(c1.$1.toDouble(), c2.$1.toDouble(), u), _mix(c1.$2.toDouble(), c2.$2.toDouble(), u), _mix(c1.$3.toDouble(), c2.$3.toDouble(), u));
}

double _segDist(double px, double py, (double, double) a, (double, double) b) {
  final vx = b.$1 - a.$1;
  final vy = b.$2 - a.$2;
  final wx = px - a.$1;
  final wy = py - a.$2;
  final len2 = vx * vx + vy * vy;
  final t = (len2 == 0 ? 0.0 : (wx * vx + wy * vy) / len2).clamp(0.0, 1.0);
  final cx = a.$1 + vx * t - px;
  final cy = a.$2 + vy * t - py;
  return math.sqrt(cx * cx + cy * cy);
}

// ---- Minimal PNG encoder ---------------------------------------------------

Uint8List _png(Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0); // filter: none
    raw.add(rgba.sublist(y * size * 4, (y + 1) * size * 4));
  }
  final compressed = ZLibCodec(level: 9).encode(raw.takeBytes());

  final out = BytesBuilder();
  out.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final ihdr = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  _chunk(out, 'IHDR', ihdr.buffer.asUint8List());
  _chunk(out, 'IDAT', Uint8List.fromList(compressed));
  _chunk(out, 'IEND', Uint8List(0));
  return out.takeBytes();
}

void _chunk(BytesBuilder out, String type, Uint8List data) {
  final typeBytes = type.codeUnits;
  final len = ByteData(4)..setUint32(0, data.length);
  out.add(len.buffer.asUint8List());
  final body = Uint8List(4 + data.length)
    ..setRange(0, 4, typeBytes)
    ..setRange(4, 4 + data.length, data);
  out.add(body);
  final crc = ByteData(4)..setUint32(0, _crc32(body));
  out.add(crc.buffer.asUint8List());
}

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(Uint8List bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
