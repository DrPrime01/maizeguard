import 'dart:io';
import 'dart:math' as math;

import '../domain/models/disease_class.dart';
import 'classifier.dart';
import 'prediction.dart';

/// Stand-in classifier used until the trained model is exported.
///
/// It exists so the entire pipeline downstream of inference — GPS capture,
/// persistence, the map, sync, the low-confidence retake path — can be built
/// and demonstrated before training finishes. Swapping in [TfliteClassifier]
/// is a one-line provider change.
///
/// Results are derived from the image bytes, so they are deterministic: the
/// same photo always yields the same prediction. That makes the app
/// demonstrable and the acceptance tests repeatable. The distribution is
/// deliberately spread so that some images land below any sensible threshold,
/// which is what exercises FR-06 / AT-03.
class StubClassifier implements DiseaseClassifier {
  StubClassifier({this.simulatedLatency = const Duration(milliseconds: 120)});

  /// Stands in for real inference time so loading states are exercised.
  final Duration simulatedLatency;

  @override
  List<DiseaseClass> get labels => DiseaseClass.values;

  @override
  Future<void> load() async {}

  @override
  Future<Prediction> classify(File image) async {
    final stopwatch = Stopwatch()..start();
    final bytes = await image.readAsBytes();
    await Future<void>.delayed(simulatedLatency);

    // FNV-1a over a sample of the bytes: stable across runs, cheap on large
    // photos, and sensitive enough that two different images diverge.
    var hash = 0x811c9dc5;
    final step = bytes.length > 4096 ? bytes.length ~/ 4096 : 1;
    for (var i = 0; i < bytes.length; i += step) {
      hash = ((hash ^ bytes[i]) * 0x01000193) & 0xffffffff;
    }

    final random = math.Random(hash);
    final logits = List<double>.generate(
      DiseaseClass.values.length,
      (_) => random.nextDouble() * 6.0,
    );
    final max = logits.reduce(math.max);
    final exps = logits.map((v) => math.exp(v - max)).toList();
    final sum = exps.fold<double>(0, (a, b) => a + b);

    stopwatch.stop();
    return Prediction(
      probabilities: exps.map((e) => e / sum).toList(),
      inferenceMs: stopwatch.elapsedMilliseconds,
    );
  }

  @override
  void dispose() {}
}
