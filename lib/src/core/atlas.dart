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
