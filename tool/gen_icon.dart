// Generates assets/icon/icon.png: teal field, two interlocked white rings.
// Run from the repo root: dart run tool/gen_icon.dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  final icon = img.Image(width: size, height: size);
  final bg = img.ColorRgb8(0, 121, 107); // teal 700
  final fg = img.ColorRgb8(255, 255, 255);

  img.fill(icon, color: bg);

  void ring(int cx, int cy) {
    img.fillCircle(icon, x: cx, y: cy, radius: 240, color: fg);
    img.fillCircle(icon, x: cx, y: cy, radius: 168, color: bg);
  }

  // Two overlapping rings, offset diagonally — the second ring's hole
  // punches through the first, giving the linked look.
  ring(430, 430);
  ring(594, 594);

  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(icon));
  stdout.writeln('wrote assets/icon/icon.png');
}
