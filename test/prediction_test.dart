import 'package:flutter_test/flutter_test.dart';
import 'package:maize_guard/domain/models/disease_class.dart';
import 'package:maize_guard/ml/prediction.dart';

void main() {
  group('Prediction', () {
    test('picks the highest-scoring label', () {
      // order: msv, common_rust, grey_leaf_spot, healthy
      final prediction = Prediction(
        probabilities: const [0.10, 0.72, 0.13, 0.05],
        inferenceMs: 40,
      );
      expect(prediction.label, DiseaseClass.commonRust);
      expect(prediction.confidence, closeTo(0.72, 1e-9));
    });

    test('ranks all classes most to least likely', () {
      final prediction = Prediction(
        probabilities: const [0.10, 0.72, 0.13, 0.05],
        inferenceMs: 40,
      );
      expect(
        prediction.ranked.map((e) => e.label).toList(),
        [
          DiseaseClass.commonRust,
          DiseaseClass.greyLeafSpot,
          DiseaseClass.msv,
          DiseaseClass.healthy,
        ],
      );
    });

    group('AT-03 low-confidence handling', () {
      final prediction = Prediction(
        probabilities: const [0.10, 0.72, 0.13, 0.05],
        inferenceMs: 40,
      );

      test('accepts at or above the threshold', () {
        expect(prediction.isAcceptedAt(0.70), isTrue);
        // Boundary: exactly equal to the threshold counts as accepted.
        expect(prediction.isAcceptedAt(0.72), isTrue);
      });

      test('rejects below the threshold', () {
        expect(prediction.isAcceptedAt(0.73), isFalse);
        expect(prediction.isAcceptedAt(0.95), isFalse);
      });
    });

    test('AT-11: rejects a model that does not emit exactly four classes', () {
      expect(
        () => Prediction(probabilities: const [0.5, 0.5], inferenceMs: 1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => Prediction(
          probabilities: const [0.2, 0.2, 0.2, 0.2, 0.2],
          inferenceMs: 1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
