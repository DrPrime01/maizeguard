import '../domain/models/disease_class.dart';

/// The outcome of running one image through the classifier.
class Prediction {
  Prediction({
    required this.probabilities,
    required this.inferenceMs,
  }) : assert(
          probabilities.length == DiseaseClass.values.length,
          'Model returned ${probabilities.length} probabilities but the label '
          'set has ${DiseaseClass.values.length} entries (AT-11).',
        );

  /// One probability per [DiseaseClass], in declaration order.
  final List<double> probabilities;

  /// Wall-clock time for preprocessing plus inference (AT-10).
  final int inferenceMs;

  /// The highest-scoring label.
  DiseaseClass get label {
    var bestIndex = 0;
    for (var i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > probabilities[bestIndex]) bestIndex = i;
    }
    return DiseaseClass.values[bestIndex];
  }

  /// Top-1 probability, 0.0-1.0.
  double get confidence => probabilities[label.index];

  /// Labels ranked most to least likely — shown on the result screen so a user
  /// can see what the model considered as the runner-up.
  List<({DiseaseClass label, double probability})> get ranked {
    final entries = [
      for (var i = 0; i < probabilities.length; i++)
        (label: DiseaseClass.values[i], probability: probabilities[i]),
    ]..sort((a, b) => b.probability.compareTo(a.probability));
    return entries;
  }

  /// FR-06 / AT-03: below the threshold the result must not be treated as
  /// reliable. The decision lives here, not in the UI, so the same rule is
  /// applied everywhere and can be unit tested.
  bool isAcceptedAt(double threshold) => confidence >= threshold;
}
