import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../domain/models/scan.dart';
import '../../domain/models/sync_status.dart';
import '../shared/empty_state.dart';

/// Dashboard: start a scan, see recent observations, see sync state (PRD §17).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;
    final statsAsync = ref.watch(scanStatsProvider);
    final historyAsync = ref.watch(historyProvider);

    // Watched, not read: instantiating SyncController is what registers the
    // connectivity listener that drives automatic upload (FR-10 / AT-06).
    // Without this the sweep would only ever run when a save or a manual tap
    // happened to trigger it.
    ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MaizeGuard'),
        actions: [
          IconButton(
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncControllerProvider.notifier).syncNow();
          ref.invalidate(scanStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Hello${user?.email.isNotEmpty == true ? ', ${user!.email.split('@').first}' : ''}',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Photograph a maize leaf to check it for disease.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: () => context.push(Routes.detect),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan a leaf'),
            ),
            const SizedBox(height: 20),

            const _SyncStatusCard(),
            const SizedBox(height: 16),

            statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (stats) => stats.total == 0
                  ? const SizedBox.shrink()
                  : _StatsRow(
                      total: stats.total,
                      pending: stats.pending,
                      averageMs: stats.averageInferenceMs,
                    ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Text('Recent observations',
                      style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () => context.go(Routes.history),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 4),

            historyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Could not load observations: $error'),
              ),
              data: (scans) => scans.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: EmptyState(
                        icon: Icons.eco_outlined,
                        title: 'No observations yet',
                        message:
                            'Your saved scans will appear here, and on the map.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final scan in scans.take(5))
                          ScanTile(scan: scan),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.pending,
    required this.averageMs,
  });

  final int total;
  final int pending;
  final double averageMs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatTile(label: 'Observations', value: '$total')),
        const SizedBox(width: 12),
        Expanded(child: _StatTile(label: 'Pending sync', value: '$pending')),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Avg inference',
            value: '${averageMs.toStringAsFixed(0)} ms',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusCard extends ConsumerWidget {
  const _SyncStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canSync = ref.watch(authServiceProvider).supportsSync;
    final online = ref.watch(isOnlineProvider).value;
    final stats = ref.watch(scanStatsProvider).value;
    final pending = stats?.pending ?? 0;

    final (IconData icon, String title, String subtitle) = switch ((
      canSync,
      online,
      pending
    )) {
      (false, _, _) => (
          Icons.phonelink_off,
          'Local mode',
          'Firebase is not configured. Records stay on this device.',
        ),
      (true, false, _) => (
          Icons.cloud_off,
          'Offline',
          pending == 0
              ? 'Detection works without internet.'
              : '$pending observation${pending == 1 ? '' : 's'} waiting to sync.',
        ),
      (true, _, 0) => (
          Icons.cloud_done_outlined,
          'All synced',
          'Every observation has reached the cloud.',
        ),
      (true, _, _) => (
          Icons.cloud_upload_outlined,
          '$pending waiting to sync',
          'Tap to upload now.',
        ),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(subtitle),
        trailing: canSync && pending > 0
            ? IconButton(
                icon: const Icon(Icons.sync),
                onPressed: () =>
                    ref.read(syncControllerProvider.notifier).syncNow(),
              )
            : null,
        onTap: canSync && pending > 0
            ? () => ref.read(syncControllerProvider.notifier).syncNow()
            : null,
      ),
    );
  }
}

/// A single observation row, shared by the dashboard and the history screen.
class ScanTile extends StatelessWidget {
  const ScanTile({required this.scan, this.onTap, super.key});

  final Scan scan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scan.disease.colour.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(scan.disease.icon, color: scan.disease.colour),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                scan.disease.displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (!scan.accepted) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Saved below the confidence threshold',
                child: Icon(Icons.warning_amber_rounded,
                    size: 16, color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${(scan.confidence * 100).toStringAsFixed(0)}%  ·  '
          '${DateFormat('d MMM, HH:mm').format(scan.capturedAt)}'
          '${scan.hasLocation ? '' : '  ·  no GPS'}',
        ),
        trailing: Icon(
          switch (scan.syncStatus) {
            SyncStatus.synced => Icons.cloud_done_outlined,
            SyncStatus.pending => Icons.schedule,
            SyncStatus.failed => Icons.cloud_off,
          },
          size: 18,
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}
