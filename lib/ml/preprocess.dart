import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Input edge length expected by the model (PRD §9.1: 224 x 224).
const int kModelInputSize = 224;

/// Decodes, squares, resizes, and normalises a captured photo into the tensor
/// layout MobileNetV2 expects (FR-03).
abstract final class Preprocess {
  /// Centre-crops to a square before resizing.
  ///
  /// Phone cameras produce 4:3 or 16:9 frames. Squashing that straight to
  /// 224x224 distorts lesion shape — and lesion *shape* is exactly what
  /// separates Grey Leaf Spot's rectangles from Common Rust's ovals, so a
  /// non-uniform scale would destroy the most discriminative feature.
  static img.Image centreCropSquare(img.Image source) {
    final edge = source.width < source.height ? source.width : source.height;
    final x = (source.width - edge) ~/ 2;
    final y = (source.height - edge) ~/ 2;
    return img.copyCrop(source, x: x, y: y, width: edge, height: edge);
  }

  /// Produces a `[1, 224, 224, 3]` float buffer scaled to [-1, 1].
  ///
  /// This scaling is `tf.keras.applications.mobilenet_v2.preprocess_input`.
  /// The training notebook must use the same one — a mismatch here does not
  /// crash, it just quietly wrecks accuracy, so the two are documented as a
  /// pair in `ml/README.md`.
  static Float32List toModelInput(img.Image source) {
    final square = centreCropSquare(source);
    final resized = img.copyResize(
      square,
      width: kModelInputSize,
      height: kModelInputSize,
      interpolation: img.Interpolation.linear,
    );

    final buffer = Float32List(kModelInputSize * kModelInputSize * 3);
    var i = 0;
    for (var y = 0; y < kModelInputSize; y++) {
      for (var x = 0; x < kModelInputSize; x++) {
        final pixel = resized.getPixel(x, y);
        buffer[i++] = (pixel.r / 127.5) - 1.0;
        buffer[i++] = (pixel.g / 127.5) - 1.0;
        buffer[i++] = (pixel.b / 127.5) - 1.0;
      }
    }
    return buffer;
  }

  /// Decodes raw file bytes, returning null if the bytes are not a readable
  /// image (FR-02 validation step).
  static img.Image? decode(Uint8List bytes) => img.decodeImage(bytes);
}
