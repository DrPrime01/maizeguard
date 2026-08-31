import 'dart:io';

import '../domain/models/disease_class.dart';
import 'prediction.dart';

/// The seam between the app and whatever is actually doing the classifying.
///
/// Two implementations exist: [TfliteClassifier] for the real exported model
/// and a stub used until training completes. Everything downstream — the detect
/// flow, persistence, the map — is written against this interface only.
abstract interface class DiseaseClassifier {
  /// Loads the model. Safe to call more than once.
  Future<void> load();

  /// Classifies a captured leaf image.
  Future<Prediction> classify(File image);

  /// AT-11: the exact label set this classifier can emit.
  List<DiseaseClass> get labels;

  void dispose();
}
