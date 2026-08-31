import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/app_config.dart';
import '../../domain/models/disease_class.dart';
import '../../domain/models/scan.dart';
import '../shared/empty_state.dart';

/// FR-11: GPS-tagged observations as points on a Google Map.
///
/// Points come from the local database, so the pins themselves are available
/// offline — only the map tiles need a network. The MVP is deliberately
/// point-based rather than drawing disease boundary polygons (PRD §10, §20).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _controller;
  final Set<DiseaseClass> _visible = DiseaseClass.values.toSet();

  Set<Marker> _markers(List<Scan> scans) {
    return {
      for (final scan in scans)
        if (_visible.contains(scan.disease))
          Marker(
            markerId: MarkerId(scan.id),
            position: LatLng(scan.latitude!, scan.longitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(scan.disease.markerHue),
            infoWindow: InfoWindow(
              title: scan.disease.displayName,
              snippet:
                  '${(scan.confidence * 100).toStringAsFixed(0)}%  ·  '
                  '${DateFormat('d MMM yyyy').format(scan.capturedAt)}',
            ),
          ),
    };
  }

  CameraPosition _initialCamera(List<Scan> scans) {
    if (scans.isEmpty) {
      return const CameraPosition(
        target: LatLng(AppConfig.fallbackLatitude, AppConfig.fallbackLongitude),
        zoom: 10,
      );
    }
    return CameraPosition(
      target: LatLng(scans.first.latitude!, scans.first.longitude!),
      zoom: AppConfig.mapDetailZoom - 2,
    );
  }

  /// Frames every visible observation once they are loaded.
  Future<void> _fitToScans(List<Scan> scans) async {
    final controller = _controller;
    if (controller == null || scans.length < 2) return;

    final lats = scans.map((s) => s.latitude!);
    final lngs = scans.map((s) => s.longitude!);
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b),
          lngs.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b),
          lngs.reduce((a, b) => a > b ? a : b)),
    );
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
  }

  @override
  Widget build(BuildContext context) {
    final scansAsync = ref.watch(mappableScansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Disease map')),
      body: scansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load map: $error')),
        data: (scans) {
          if (scans.isEmpty) {
            return const EmptyState(
              icon: Icons.map_outlined,
              title: 'Nothing to map yet',
              message:
                  'Observations saved with GPS coordinates appear here as pins.',
            );
          }
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _initialCamera(scans),
                markers: _markers(scans),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                mapToolbarEnabled: false,
                onMapCreated: (controller) {
                  _controller = controller;
                  _fitToScans(scans);
                },
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _Legend(
                  visible: _visible,
                  counts: {
                    for (final d in DiseaseClass.values)
                      d: scans.where((s) => s.disease == d).length,
                  },
                  onToggle: (disease) => setState(() {
                    if (!_visible.remove(disease)) _visible.add(disease);
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Doubles as a legend and a filter — tapping a class hides or shows its pins.
class _Legend extends StatelessWidget {
  const _Legend({
    required this.visible,
    required this.counts,
    required this.onToggle,
  });

  final Set<DiseaseClass> visible;
  final Map<DiseaseClass, int> counts;
  final ValueChanged<DiseaseClass> onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (final disease in DiseaseClass.values)
              FilterChip(
                selected: visible.contains(disease),
                onSelected: (_) => onToggle(disease),
                avatar: CircleAvatar(
                  backgroundColor: disease.colour,
                  radius: 7,
                ),
                label: Text('${disease.shortName} (${counts[disease] ?? 0})'),
              ),
          ],
        ),
      ),
    );
  }
}
