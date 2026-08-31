/// The fixed label set for the deployed model.
///
/// PRD Rev. 2 §8 / AT-11: model output is restricted to exactly these four
/// labels. The declaration order here IS the model's output tensor order —
/// changing it silently remaps every prediction, so it must stay in lockstep
/// with `assets/model/labels.txt` and the training notebook's class order.
enum DiseaseClass {
  msv('msv', 'Maize Streak Virus', 'MSV'),
  commonRust('common_rust', 'Common Rust', 'Rust'),
  greyLeafSpot('grey_leaf_spot', 'Grey Leaf Spot', 'GLS'),
  healthy('healthy', 'Healthy', 'Healthy');

  const DiseaseClass(this.id, this.displayName, this.shortName);

  /// Stable identifier used in the database, in Firestore, and in labels.txt.
  final String id;

  /// Full human-readable name shown on the result and detail screens.
  final String displayName;

  /// Compact name for map pins and dense list rows.
  final String shortName;

  bool get isDisease => this != DiseaseClass.healthy;

  static DiseaseClass fromId(String id) => values.firstWhere(
        (d) => d.id == id,
        orElse: () => throw ArgumentError('Unknown disease id: $id'),
      );

  /// Null-safe lookup for data of uncertain provenance (e.g. a Firestore doc
  /// written by an older build).
  static DiseaseClass? tryFromId(String? id) {
    if (id == null) return null;
    for (final d in values) {
      if (d.id == id) return d;
    }
    return null;
  }
}
