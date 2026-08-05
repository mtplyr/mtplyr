// Erzeugt das grüne Nina-App-Icon (iOS) in allen benötigten Größen.
// Motiv: diagonaler Teal-Verlauf + weißes Radar/Broadcast-Zeichen (Punkt + 2 Ringe),
// passend zum In-App-Logo (Kreis + sensors-Icon).
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

  // Farben (Nina): Teal-Verlauf hell -> dunkel, weißes Motiv.
  const r1 = 95, g1 = 201, b1 = 166; // #5FC9A6
  const r2 = 62, g2 = 158, b2 = 134; // #3E9E86
  final c = (S - 1) / 2.0;
  final dotR = 0.100 * S;
  final ring1i = 0.165 * S, ring1o = 0.225 * S;
  final ring2i = 0.290 * S, ring2o = 0.350 * S;

  for (var y = 0; y < S; y++) {
    for (var x = 0; x < S; x++) {
      // diagonaler Verlauf
      final t = (x + y) / (2 * (S - 1));
      var r = (r1 + (r2 - r1) * t).round();
      var g = (g1 + (g2 - g1) * t).round();
      var b = (b1 + (b2 - b1) * t).round();
      // weißes Radar-Zeichen
      final d = sqrt((x - c) * (x - c) + (y - c) * (y - c));
      final white = d <= dotR ||
          (d >= ring1i && d <= ring1o) ||
          (d >= ring2i && d <= ring2o);
      if (white) { r = 255; g = 255; b = 255; }
      master.setPixelRgb(x, y, r, g, b);
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
