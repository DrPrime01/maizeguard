import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/disease_catalogue.dart';

/// FR-13: the supported disease catalogue.
class DiseaseListScreen extends StatelessWidget {
  const DiseaseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Diseases')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'This app is trained to recognise three maize diseases prevalent in '
            'South-West Nigeria, plus healthy leaves.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (final info in DiseaseCatalogue.all)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: info.diseaseClass.colour.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(info.diseaseClass.icon,
                      color: info.diseaseClass.colour),
                ),
                title: Text(info.diseaseClass.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(info.pathogen,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push('/diseases/${info.diseaseClass.id}'),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Diseases outside these classes — including Fusarium ear '
                      'rot, downy mildew and bacterial stalk rot — are not '
                      'detected by this model and may be misclassified as one '
                      'of the four above.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
