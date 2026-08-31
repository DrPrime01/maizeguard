import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/app_config.dart';

/// Outcome of a location request. Modelled explicitly rather than as a
/// nullable position so the UI can explain *why* coordinates are missing
/// instead of silently dropping them (FR-07 / AT-04).
sealed class LocationResult {
  const LocationResult();
}

class LocationFix extends LocationResult {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

/// The device's location services are switched off entirely.
class LocationServiceDisabled extends LocationResult {
  const LocationServiceDisabled();
}

/// Permission refused for this session.
class LocationPermissionDenied extends LocationResult {
  const LocationPermissionDenied({required this.permanently});

  /// True when the user selected "don't ask again" — the app must send them to
  /// system settings rather than re-prompting, which Android will ignore.
  final bool permanently;
}

/// No fix arrived within [AppConfig.locationTimeout].
class LocationUnavailable extends LocationResult {
  const LocationUnavailable(this.reason);

  final String reason;
}

/// Wraps geolocator so the rest of the app never touches the plugin directly.
class LocationService {
  const LocationService();

  /// Requests a single fix, degrading gracefully.
  ///
  /// Deliberately never throws: a missing GPS fix must not cost the user their
  /// scan. The caller saves the observation either way and records that it has
  /// no coordinates.
  Future<LocationResult> currentPosition({
    Duration timeout = AppConfig.locationTimeout,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationServiceDisabled();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationPermissionDenied(permanently: true);
      }
      if (permission == LocationPermission.denied) {
        return const LocationPermissionDenied(permanently: false);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on TimeoutException {
      return const LocationUnavailable('No GPS fix within the time limit');
    } on LocationServiceDisabledException {
      return const LocationServiceDisabled();
    } catch (e) {
      return LocationUnavailable(e.toString());
    }
  }
}
