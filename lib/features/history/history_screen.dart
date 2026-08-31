import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/disease_class.dart';
import '../../domain/models/scan.dart';
import '../../domain/models/sync_status.dart';
import '../home/home_screen.dart';
import '../shared/empty_state.dart';

/// FR-12 / AT-08: the signed-in user's stored observations.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DiseaseClass? _filter;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load history: $error')),
        data: (all) {
          final scans =
              _filter == null ? all : all.where((s) => s.disease == _filter).toList();

          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ChoiceChip(
                        label: Text('All (${all.length})'),
                        selected: _filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                    ),
                    for (final disease in DiseaseClass.values)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                        child: ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: disease.colour,
                            radius: 7,
                          ),
                          label: Text(
                            '${disease.shortName} '
                            '(${all.where((s) => s.disease == disease).length})',
                          ),
                          selected: _filter == disease,
                          onSelected: (_) => setState(() => _filter = disease),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: scans.isEmpty
                    ? EmptyState(
                        icon: Icons.history,
                        title: _filter == null
                            ? 'No observations yet'
                            : 'Nothing for ${_filter!.displayName}',
                        message: _filter == null
                            ? 'Saved scans appear here with their location and sync state.'
                            : 'Try a different filter.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await ref.read(syncControllerProvider.notifier).syncNow();
                          ref.invalidate(historyProvider);
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          itemCount: scans.length,
                          itemBuilder: (context, index) => ScanTile(
                            scan: scans[index],
                            onTap: () => _showDetail(scans[index]),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDetail(Scan scan) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ScanDetailSheet(scan: scan),
    );
  }
}

class _ScanDetailSheet extends StatelessWidget {
  const _ScanDetailSheet({required this.scan});

  final Scan scan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = File(scan.imagePath);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image.existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(image,
                    height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(scan.disease.icon, color: scan.disease.colour),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(scan.disease.displayName,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row(context, 'Confidence',
                '${(scan.confidence * 100).toStringAsFixed(1)}%'),
            _row(
              context,
              'Status',
              scan.accepted
                  ? 'Accepted'
                  : 'Unconfirmed (below ${(scan.thresholdUsed * 100).toStringAsFixed(0)}% threshold)',
            ),
            _row(context, 'Captured',
                DateFormat('d MMMM yyyy, HH:mm').format(scan.capturedAt)),
            _row(
              context,
              'Location',
              scan.hasLocation
                  ? '${scan.latitude!.toStringAsFixed(5)}, '
                      '${scan.longitude!.toStringAsFixed(5)}'
                      '${scan.accuracyMeters == null ? '' : ' (±${scan.accuracyMeters!.toStringAsFixed(0)} m)'}'
                  : 'Not recorded',
            ),
            _row(context, 'Inference time', '${scan.inferenceMs} ms'),
            _row(
              context,
              'Sync',
              switch (scan.syncStatus) {
                SyncStatus.synced => 'Uploaded',
                SyncStatus.pending => 'Waiting for connection',
                SyncStatus.failed => 'Upload failed — will retry',
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
