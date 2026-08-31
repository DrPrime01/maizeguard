/// Tunable behaviour that is not a build-time constant.
abstract final class AppConfig {
  /// Default confidence threshold for accepting a prediction (FR-06).
  ///
  /// PRD §9.2 quotes 95% as the Chapter 3 *example* threshold, and §20 flags
  /// that the final value must be justified from validation results rather
  /// than assumed. 0.70 is used as a working default until those results
  /// exist; the value is user-adjustable in Settings and is recorded on every
  /// scan (`Scan.thresholdUsed`) so past observations stay interpretable.
  static const double defaultConfidenceThreshold = 0.70;

  static const double minConfidenceThreshold = 0.50;
  static const double maxConfidenceThreshold = 0.99;

  /// How long to wait for a GPS fix before saving the observation without one.
  /// A farmer under tree cover should not be blocked from recording a scan.
  static const Duration locationTimeout = Duration(seconds: 12);

  /// Map camera zoom used when focusing a single observation.
  static const double mapDetailZoom = 16;

  /// Fallback map centre (Ibadan, South-West Nigeria) for a first run with no
  /// observations and no location permission.
  static const double fallbackLatitude = 7.3775;
  static const double fallbackLongitude = 3.9470;

  /// Settings keys.
  static const String keyConfidenceThreshold = 'confidence_threshold';
}
