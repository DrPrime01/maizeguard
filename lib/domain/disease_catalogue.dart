import 'models/disease_class.dart';

/// Reference information for one entry in the supported label set.
class DiseaseInfo {
  const DiseaseInfo({
    required this.diseaseClass,
    required this.pathogen,
    required this.summary,
    required this.symptoms,
    required this.conditions,
    required this.confusableWith,
  });

  final DiseaseClass diseaseClass;

  /// Causal organism, or a plain description for the healthy class.
  final String pathogen;
  final String summary;

  /// Field-visible signs, ordered most to least distinctive.
  final List<String> symptoms;

  /// Conditions that favour the disease.
  final String conditions;

  /// What this is most often mistaken for — the app shows this to help a user
  /// sanity-check a prediction they doubt.
  final String confusableWith;
}

/// FR-13: metadata for the three supported diseases plus Healthy.
///
/// Identification information only. Treatment and control recommendations are
/// explicitly out of scope (PRD §5.2, §20) and must not be added here.
abstract final class DiseaseCatalogue {
  static const Map<DiseaseClass, DiseaseInfo> _entries = {
    DiseaseClass.msv: DiseaseInfo(
      diseaseClass: DiseaseClass.msv,
      pathogen: 'Maize streak virus (genus Mastrevirus)',
      summary:
          'A viral disease spread by leafhoppers (Cicadulina spp.), not by '
          'contact or soil. One of the most damaging maize diseases in '
          'sub-Saharan Africa, especially where planting is staggered.',
      symptoms: [
        'Narrow, broken yellow or white streaks running parallel to the leaf veins',
        'Streaks widen and merge as the leaf ages, giving a striped appearance',
        'Youngest leaves show symptoms first',
        'Severe stunting and poor cob formation when infection happens early',
      ],
      conditions:
          'Follows leafhopper movement; worst in late or staggered plantings '
          'and near grassy field margins that host the vector.',
      confusableWith:
          'Nutrient deficiency striping and herbicide damage, which usually '
          'run the full length of the leaf rather than appearing as broken streaks.',
    ),
    DiseaseClass.commonRust: DiseaseInfo(
      diseaseClass: DiseaseClass.commonRust,
      pathogen: 'Puccinia sorghi',
      summary:
          'A fungal disease producing raised pustules that rupture to release '
          'powdery spores. Usually tolerable at low levels but damaging when '
          'it establishes early on susceptible varieties.',
      symptoms: [
        'Small oval pustules scattered on both upper and lower leaf surfaces',
        'Cinnamon-brown to reddish-brown powder released when a pustule is rubbed',
        'Pustules darken towards brownish-black as the crop matures',
        'Leaf tissue around heavy infection yellows and dies back',
      ],
      conditions:
          'Favoured by cool, humid weather (roughly 16-23 C) with heavy dew '
          'and long periods of leaf wetness.',
      confusableWith:
          'Southern rust, whose pustules are smaller, more orange, and '
          'concentrated on the upper leaf surface.',
    ),
    DiseaseClass.greyLeafSpot: DiseaseInfo(
      diseaseClass: DiseaseClass.greyLeafSpot,
      pathogen: 'Cercospora zeae-maydis',
      summary:
          'A fungal leaf-spot disease that survives on crop residue. Lesions '
          'are boxed in by the leaf veins, which gives them their '
          'characteristic rectangular outline.',
      symptoms: [
        'Narrow, rectangular grey to tan lesions with sharply parallel edges',
        'Lesions bounded by the veins and running parallel to them',
        'Begins as small necrotic spots, often with a yellow halo when backlit',
        'Lesions merge under pressure, blighting whole leaves from the bottom up',
      ],
      conditions:
          'Favoured by warm, humid weather with prolonged leaf wetness; '
          'builds up where maize residue is left on the surface.',
      confusableWith:
          'Northern leaf blight, whose lesions are longer, cigar-shaped, and '
          'not confined by the veins.',
    ),
    DiseaseClass.healthy: DiseaseInfo(
      diseaseClass: DiseaseClass.healthy,
      pathogen: 'No disease detected',
      summary:
          'The leaf shows no signs of the three diseases this app is trained '
          'to recognise.',
      symptoms: [
        'Uniform green colour across the leaf blade',
        'No pustules, streaks, or defined lesions',
        'Intact leaf margins and tip',
      ],
      conditions: 'Not applicable.',
      confusableWith:
          'Very early infection may not yet be visible. A healthy result is '
          'not a guarantee the plant is disease-free.',
    ),
  };

  static DiseaseInfo of(DiseaseClass diseaseClass) => _entries[diseaseClass]!;

  static List<DiseaseInfo> get all =>
      DiseaseClass.values.map(of).toList(growable: false);

  /// Diseases only, excluding Healthy — used by the catalogue screen listing
  /// "the three supported diseases" (PRD §17).
  static List<DiseaseInfo> get diseasesOnly =>
      all.where((e) => e.diseaseClass.isDisease).toList(growable: false);
}
