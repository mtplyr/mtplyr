// Erzeugt das Vela-App-Icon (blauer Play-Button, wie das In-App-Logo)
// in allen iOS- und Android-Groessen. Aufruf: dart run tool/gen_icon.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  final base = img.Image(width: size, height: size, numChannels: 3);

  // Diagonaler Blau-Verlauf kBlue (#6FB1F2) -> kBlue2 (#4685C4)
  const c1 = [0x6F, 0xB1, 0xF2];
  const c2 = [0x46, 0x85, 0xC4];
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (2 * size);
      final r = (c1[0] + (c2[0] - c1[0]) * t).round();
      final g = (c1[1] + (c2[1] - c1[1]) * t).round();
      final b = (c1[2] + (c2[2] - c1[2]) * t).round();
      base.setPixelRgb(x, y, r, g, b);
    }
  }

  // Weisses Play-Dreieck (nach rechts zeigend), leicht abgerundet wirkend
  final cx = size / 2, cy = size / 2;
  final w = size * 0.30, h = size * 0.36;
  final ax = cx - w / 2, ay1 = cy - h / 2, ay2 = cy + h / 2; // linke Kante
  final bx = cx + w / 2, by = cy; // Spitze rechts
  double sign(double px, double py, double x1, double y1, double x2, double y2) =>
      (px - x2) * (y1 - y2) - (x1 - x2) * (py - y2);
  for (var y = ay1.floor(); y <= ay2.ceil(); y++) {
    for (var x = ax.floor(); x <= bx.ceil(); x++) {
      final fx = x.toDouble(), fy = y.toDouble();
      final d1 = sign(fx, fy, ax, ay1, bx, by);
      final d2 = sign(fx, fy, bx, by, ax, ay2);
      final d3 = sign(fx, fy, ax, ay2, ax, ay1);
      final neg = d1 < 0 || d2 < 0 || d3 < 0;
      final pos = d1 > 0 || d2 > 0 || d3 > 0;
      if (!(neg && pos)) base.setPixelRgb(x, y, 0xFF, 0xFF, 0xFF);
    }
  }

  const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  const ios = {
    'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40, 'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29, 'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80, 'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120, 'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76, 'Icon-App-76x76@2x.png': 152, 'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  ios.forEach((name, sz) {
    final out = img.copyResize(base, width: sz, height: sz, interpolation: img.Interpolation.cubic);
    File('$iosDir/$name').writeAsBytesSync(img.encodePng(out));
  });

  const andr = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
  andr.forEach((d, sz) {
    final out = img.copyResize(base, width: sz, height: sz, interpolation: img.Interpolation.cubic);
    File('android/app/src/main/res/mipmap-$d/ic_launcher.png').writeAsBytesSync(img.encodePng(out));
  });

  // Launch-Logo (blaue Rundung + Play, transparenter Rand) fuer den iOS-Splash.
  img.Image launchLogo(int px) {
    final canvas = img.Image(width: px, height: px, numChannels: 4);
    // transparent
    for (var y = 0; y < px; y++) {
      for (var x = 0; x < px; x++) {
        canvas.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
    final pad = px * 0.14;
    final side = px - 2 * pad;
    final rad = side * 0.28;
    bool inRounded(double x, double y) {
      final lx = x - pad, ly = y - pad;
      if (lx < 0 || ly < 0 || lx > side || ly > side) return false;
      final dx = lx < rad ? rad - lx : (lx > side - rad ? lx - (side - rad) : 0.0);
      final dy = ly < rad ? rad - ly : (ly > side - rad ? ly - (side - rad) : 0.0);
      return dx * dx + dy * dy <= rad * rad;
    }
    for (var y = 0; y < px; y++) {
      for (var x = 0; x < px; x++) {
        if (inRounded(x.toDouble(), y.toDouble())) {
          final t = (x + y) / (2 * px);
          final r = (c1[0] + (c2[0] - c1[0]) * t).round();
          final g = (c1[1] + (c2[1] - c1[1]) * t).round();
          final b = (c1[2] + (c2[2] - c1[2]) * t).round();
          canvas.setPixelRgba(x, y, r, g, b, 255);
        }
      }
    }
    final lcx = px / 2, lcy = px / 2;
    final lw = px * 0.26, lh = px * 0.30;
    final lax = lcx - lw / 2, lay1 = lcy - lh / 2, lay2 = lcy + lh / 2, lbx = lcx + lw / 2, lby = lcy;
    for (var y = lay1.floor(); y <= lay2.ceil(); y++) {
      for (var x = lax.floor(); x <= lbx.ceil(); x++) {
        final fx = x.toDouble(), fy = y.toDouble();
        final d1 = sign(fx, fy, lax, lay1, lbx, lby);
        final d2 = sign(fx, fy, lbx, lby, lax, lay2);
        final d3 = sign(fx, fy, lax, lay2, lax, lay1);
        final neg = d1 < 0 || d2 < 0 || d3 < 0;
        final pos = d1 > 0 || d2 > 0 || d3 > 0;
        if (!(neg && pos)) canvas.setPixelRgba(x, y, 0xFF, 0xFF, 0xFF, 255);
      }
    }
    return canvas;
  }

  const launchDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
  File('$launchDir/LaunchImage.png').writeAsBytesSync(img.encodePng(launchLogo(120)));
  File('$launchDir/LaunchImage@2x.png').writeAsBytesSync(img.encodePng(launchLogo(240)));
  File('$launchDir/LaunchImage@3x.png').writeAsBytesSync(img.encodePng(launchLogo(360)));

  stdout.writeln('Icons + Launch-Logo erzeugt.');
}
