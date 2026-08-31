import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/app_config.dart';

/// Profile and settings (PRD §17), including the two numbers the evaluation
/// needs: the confidence threshold in force and measured inference latency.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double? _draftThreshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;
    final auth = ref.watch(authServiceProvider);
    final stats = ref.watch(scanStatsProvider).value;
    final thresholdAsync = ref.watch(confidenceThresholdProvider);
    final threshold = _draftThreshold ??
        thresholdAsync.value ??
        AppConfig.defaultConfidenceThreshold;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(user?.email ?? 'Not signed in'),
              subtitle: Text(
                auth.supportsSync
                    ? 'Signed in with Firebase'
                    : 'Local account — records stay on this device',
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('Detection', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Confidence threshold')),
                      Text('${(threshold * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: threshold,
                    min: AppConfig.minConfidenceThreshold,
                    max: AppConfig.maxConfidenceThreshold,
                    divisions: 49,
                    label: '${(threshold * 100).toStringAsFixed(0)}%',
                    onChanged: (value) =>
                        setState(() => _draftThreshold = value),
                    onChangeEnd: (value) {
                      ref
                          .read(confidenceThresholdProvider.notifier)
                          .set(value);
                      setState(() => _draftThreshold = null);
                    },
                  ),
                  Text(
                    'Results below this are flagged as low confidence and are '
                    'not treated as reliable. The project paper quotes 95% as '
                    'an example only — set the final value from your model\'s '
                    'validation results, not by assumption.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.memory),
              title: const Text('Model'),
              subtitle: Text(
                kUseTrainedModel
                    ? 'MobileNetV2 (TensorFlow Lite, on-device)'
                    : 'Stub classifier — no trained model installed yet',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Average inference time'),
              subtitle: const Text('Measured on this device'),
              trailing: Text(
                stats == null || stats.total == 0
                    ? '—'
                    : '${stats.averageInferenceMs.toStringAsFixed(0)} ms',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('Data', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Stored observations'),
                  trailing: Text('${stats?.total ?? 0}'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Waiting to sync'),
                  trailing: Text('${stats?.pending ?? 0}'),
                  onTap: auth.supportsSync
                      ? () =>
                          ref.read(syncControllerProvider.notifier).syncNow()
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'MaizeGuard · Miva Open University\n'
              'Final-year project — Gabriel Shoyombo',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}
