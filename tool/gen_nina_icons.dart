// Erzeugt das grüne Nina-App-Icon (iOS) in allen benötigten Größen.
// Motiv: diagonaler Teal-Verlauf + weißer Play-Pfeil, der Broadcast-Wellen
// "sendet" (Player + Live-Signal) — passend zur Marke Nina.
//
// Lauf:  dart run tool/gen_nina_icons.dart
// Ausgabe: ios_nina_icons/Icon-App-*.png  (im Nina-Build über die Vela-Icons kopiert)
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

// iOS-Dateiname -> Kantenlänge in Pixel.
const sizes = <String, int>{
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

void main() {
  const S = 2048; // Supersample-Master -> beim Verkleinern glatte Kanten.
  final master = img.Image(width: S, height: S, numChannels: 3);

  const r1 = 95, g1 = 201, b1 = 166; // #5FC9A6
  const r2 = 62, g2 = 158, b2 = 134; // #3E9E86

  // diagonaler Teal-Verlauf
  for (var y = 0; y < S; y++) {
    for (var x = 0; x < S; x++) {
      final t = (x + y) / (2 * (S - 1));
      master.setPixelRgb(x, y,
          (r1 + (r2 - r1) * t).round(),
          (g1 + (g2 - g1) * t).round(),
          (b1 + (b2 - b1) * t).round());
    }
  }

  // Play-Dreieck (etwas nach rechts gesetzt, damit das Gesamtmotiv optisch mittig wirkt)
  final apexX = 0.545 * S, apexY = 0.50 * S;
  final leftX = 0.27 * S, topY = 0.30 * S, botY = 0.70 * S;
  img.fillPolygon(master, vertices: [
    img.Point(leftX, topY),
    img.Point(leftX, botY),
    img.Point(apexX, apexY),
  ], color: img.ColorRgb8(255, 255, 255));

  // Zwei Broadcast-Wellen rechts der Spitze (nach rechts offener Bogen)
  const maxAng = 0.62; // ~35°
  final bands = [
    [0.100 * S, 0.140 * S],
    [0.200 * S, 0.245 * S],
  ];
  for (var y = 0; y < S; y++) {
    for (var x = 0; x < S; x++) {
      final dx = x - apexX, dy = y - apexY;
      if (dx <= 0) continue;
      if (atan2(dy, dx).abs() > maxAng) continue;
      final d = sqrt(dx * dx + dy * dy);
      for (final band in bands) {
        if (d >= band[0] && d <= band[1]) { master.setPixelRgb(x, y, 255, 255, 255); break; }
      }
    }
  }

  final outDir = Directory('ios_nina_icons');
  outDir.createSync(recursive: true);
  sizes.forEach((name, px) {
    final resized = img.copyResize(master, width: px, height: px, interpolation: img.Interpolation.average);
    File('${outDir.path}/$name').writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('  $name  (${px}px)');
  });
  stdout.writeln('Fertig: ${sizes.length} Icons in ${outDir.path}/');
}
