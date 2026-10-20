import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../bindings/bindings.dart';
import 'lexicon.dart';

abstract final class Atlas {
  static final Map<int, ui.Image> _images = {};

  static ui.Image? at(int index) => _images[index];

  static ui.Image? of(A key) => _images[key.index];

  static ui.Image? forSprite(Sprite sprite) => _images[sprite.asset];

  static Future<void> loadOne(int index) async {
    if (_images.containsKey(index)) {
      return;
    }
    final data = await rootBundle.load(Lex.assetAt(index));
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _images[index] = frame.image;
  }

  /// Opaque bounds of a full-screen art, so transparent margins baked into
  /// the file never show up as empty bands.
  static ui.Rect? opaque(A key) => _opaque[key.index];

  static final Map<int, ui.Rect> _opaque = {};

  static Future<void> trim(A key) async {
    final image = _images[key.index];
    if (image == null || _opaque.containsKey(key.index)) {
      return;
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      return;
    }
    final w = image.width;
    final h = image.height;
    bool solidRow(int y) {
      for (var x = 0; x < w; x += 4) {
        if (data.getUint8((y * w + x) * 4 + 3) > 200) {
          return true;
        }
      }
      return false;
    }

    bool solidColumn(int x) {
      for (var y = 0; y < h; y += 4) {
        if (data.getUint8((y * w + x) * 4 + 3) > 200) {
          return true;
        }
      }
      return false;
    }

    var top = 0;
    while (top < h - 1 && !solidRow(top)) {
      top++;
    }
    var bottom = h - 1;
    while (bottom > top && !solidRow(bottom)) {
      bottom--;
    }
    var left = 0;
    while (left < w - 1 && !solidColumn(left)) {
      left++;
    }
    var right = w - 1;
    while (right > left && !solidColumn(right)) {
      right--;
    }
    _opaque[key.index] = ui.Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0);
  }

  static Future<void> loadAll(void Function(double progress) onProgress) async {
    final total = Lex.assetCount;
    var done = 0;
    for (var i = 0; i < total; i++) {
      await loadOne(i);
      done++;
      onProgress(done / total);
    }
  }
}
