import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/icons/logo2.png').readAsBytesSync();
  final original = img.decodePng(bytes)!;
  
  // Create a larger canvas with padding (20% on each side)
  final padding = (original.width * 0.20).round();
  final newSize = original.width + (padding * 2);
  
  // Create transparent canvas
  final canvas = img.Image(width: newSize, height: newSize, numChannels: 4);
  
  // Paste original centered
  img.compositeImage(canvas, original, dstX: padding, dstY: padding);
  
  // Save as foreground
  File('assets/icons/logo2_foreground.png').writeAsBytesSync(img.encodePng(canvas));
  print('Created logo2_foreground.png (${newSize}x$newSize) with ${padding}px padding');
}
