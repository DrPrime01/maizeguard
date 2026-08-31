import 'dart:io';
import 'dart:math' as math;

import 'package:tflite_flutter/tflite_flutter.dart';

import '../domain/models/disease_class.dart';
import 'classifier.dart';
import 'prediction.dart';
import 'preprocess.dart';

/// Runs the exported MobileNetV2 model on-device (FR-04).
///
/// Nothing here touches the network: this is the whole point of the offline
/// -first requirement, and the class must stay free of any Firebase or HTTP
/// dependency.
class TfliteClassifier implements DiseaseClassifier {
  TfliteClassifier({
    this.assetPath = 'assets/model/maize_mobilenetv2.tflite',
    this.threads = 4,
  });

  final String assetPath;
  final int threads;

  Interpreter? _interpreter;

  @override
  List<DiseaseClass> get labels => DiseaseClass.values;

  @override
  Future<void> load() async {
    if (_interpreter != null) return;
    final options = InterpreterOptions()..threads = threads;
    final interpreter = await Interpreter.fromAsset(assetPath, options: options);

    // Fail loudly at load time rather than producing silently-wrong labels at
    // inference time (AT-11).
    final outputShape = interpreter.getOutputTensor(0).shape;
    final classCount = outputShape.last;
    if (classCount != DiseaseClass.values.length) {
      interpreter.close();
      throw StateError(
        'Model at $assetPath outputs $classCount classes but the app defines '
        '${DiseaseClass.values.length} labels. The exported model and '
        'DiseaseClass are out of sync.',
      );
    }
    _interpreter = interpreter;
  }

  @override
  Future<Prediction> classify(File image) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('classify() called before load()');
    }

    final stopwatch = Stopwatch()..start();

    final bytes = await image.readAsBytes();
    final decoded = Preprocess.decode(bytes);
    if (decoded == null) {
      throw const FormatException('Captured file is not a readable image');
    }

    final input = Preprocess.toModelInput(decoded)
        .reshape([1, kModelInputSize, kModelInputSize, 3]);
    final classCount = DiseaseClass.values.length;
    final output = List.filled(classCount, 0.0).reshape([1, classCount]);

    interpreter.run(input, output);
    stopwatch.stop();

    final raw = (output[0] as List).map((v) => (v as num).toDouble()).toList();
    return Prediction(
      probabilities: _asProbabilities(raw),
      inferenceMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Accepts either a softmax head or raw logits.
  ///
  /// The training notebook exports with a softmax activation, but an
  /// int8-quantised export can drift the sum slightly, and a future re-export
  /// might omit the activation entirely. Normalising here keeps the confidence
  /// score meaningful either way.
  static List<double> _asProbabilities(List<double> raw) {
    final sum = raw.fold<double>(0, (a, b) => a + b);
    final looksNormalised =
        raw.every((v) => v >= 0 && v <= 1) && (sum - 1.0).abs() < 0.05;
    if (looksNormalised) return raw;

    final max = raw.reduce(math.max);
    final exps = raw.map((v) => math.exp(v - max)).toList();
    final expSum = exps.fold<double>(0, (a, b) => a + b);
    return exps.map((e) => e / expSum).toList();
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
