// Erzeugt das Windows-App-Icon (blaues Vela: abgerundetes Quadrat + Play-Pfeil)
// und schreibt es nach windows/runner/resources/app_icon.ico.
// Lauf: dart run tool/gen_vela_ico.dart
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  const S = 256;
  final im = img.Image(width: S, height: S, numChannels: 4);
  img.fill(im, color: img.ColorRgba8(0, 0, 0, 0)); // transparent

  // Vela-Blau-Verlauf
  const r1 = 0x6F, g1 = 0xB1, b1 = 0xF2; // #6FB1F2
  const r2 = 0x46, g2 = 0x85, b2 = 0xC4; // #4685C4
  const m = 14.0, rad = 52.0;
  final inL = m, inR = S - m, inT = m, inB = S - m;

  bool inside(double x, double y) {
    if (x < inL || x > inR || y < inT || y > inB) return false;
    double? cx, cy;
    if (x < inL + rad && y < inT + rad) { cx = inL + rad; cy = inT + rad; }
    else if (x > inR - rad && y < inT + rad) { cx = inR - rad; cy = inT + rad; }
    else if (x < inL + rad && y > inB - rad) { cx = inL + rad; cy = inB - rad; }
    else if (x > inR - rad && y > inB - rad) { cx = inR - rad; cy = inB - rad; }
    if (cx != null) return sqrt((x - cx) * (x - cx) + (y - cy!) * (y - cy)) <= rad;
    return true;
  }

  for (var y = 0; y < S; y++) {
    for (var x = 0; x < S; x++) {
      if (!inside(x + 0.5, y + 0.5)) continue;
      final t = (x + y) / (2 * (S - 1));
      im.setPixelRgba(x, y,
          (r1 + (r2 - r1) * t).round(),
          (g1 + (g2 - g1) * t).round(),
          (b1 + (b2 - b1) * t).round(), 255);
    }
  }

  // weißer Play-Pfeil
  final apexX = 0.66 * S, apexY = 0.5 * S;
  final leftX = 0.37 * S, topY = 0.33 * S, botY = 0.67 * S;
  img.fillPolygon(im, vertices: [
    img.Point(leftX, topY), img.Point(leftX, botY), img.Point(apexX, apexY),
  ], color: img.ColorRgba8(255, 255, 255, 255));

  final bytes = img.encodeIco(im);
  final f = File('windows/runner/resources/app_icon.ico');
  f.writeAsBytesSync(bytes);
  stdout.writeln('geschrieben: ${f.path} (${bytes.length} bytes)');
}
