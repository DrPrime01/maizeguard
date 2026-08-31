import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maize_guard/domain/disease_catalogue.dart';
import 'package:maize_guard/domain/models/disease_class.dart';

void main() {
  group('AT-11 scope conformance', () {
    test('exactly four labels, and they are the PRD-specified four', () {
      expect(DiseaseClass.values, hasLength(4));
      expect(
        DiseaseClass.values.map((d) => d.id).toList(),
        ['msv', 'common_rust', 'grey_leaf_spot', 'healthy'],
      );
    });

    test('labels.txt matches the enum order exactly', () {
      // The asset feeds the trained model's label mapping. If these two ever
      // drift apart, every prediction is silently mislabelled — so this is
      // asserted rather than trusted.
      final file = File('assets/model/labels.txt');
      expect(file.existsSync(), isTrue,
          reason: 'assets/model/labels.txt is missing');

      final labels = file
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      expect(labels, DiseaseClass.values.map((d) => d.id).toList());
    });

    test('only Healthy is a non-disease', () {
      expect(
        DiseaseClass.values.where((d) => !d.isDisease).toList(),
        [DiseaseClass.healthy],
      );
    });

    test('fromId rejects an unsupported class', () {
      expect(() => DiseaseClass.fromId('northern_leaf_blight'),
          throwsArgumentError);
      expect(DiseaseClass.tryFromId('fusarium_ear_rot'), isNull);
    });
  });

  group('FR-13 disease catalogue', () {
    test('every label has catalogue metadata', () {
      for (final diseaseClass in DiseaseClass.values) {
        final info = DiseaseCatalogue.of(diseaseClass);
        expect(info.pathogen, isNotEmpty);
        expect(info.summary, isNotEmpty);
        expect(info.symptoms, isNotEmpty);
      }
    });

    test('the catalogue screen lists the three diseases only', () {
      expect(DiseaseCatalogue.diseasesOnly, hasLength(3));
      expect(
        DiseaseCatalogue.diseasesOnly
            .map((i) => i.diseaseClass)
            .contains(DiseaseClass.healthy),
        isFalse,
      );
    });
  });
}
