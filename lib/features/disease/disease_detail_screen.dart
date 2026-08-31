import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/disease_catalogue.dart';
import '../../domain/models/disease_class.dart';

class DiseaseDetailScreen extends StatelessWidget {
  const DiseaseDetailScreen({required this.diseaseClass, super.key});

  final DiseaseClass diseaseClass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = DiseaseCatalogue.of(diseaseClass);

    return Scaffold(
      appBar: AppBar(title: Text(diseaseClass.displayName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: diseaseClass.colour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(diseaseClass.icon, color: diseaseClass.colour, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(diseaseClass.displayName,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(info.pathogen,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(info.summary, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),

          _Section(
            title: 'What to look for',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final symptom in info.symptoms)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 10),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: diseaseClass.colour,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(symptom,
                              style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          _Section(
            title: 'When it appears',
            child: Text(info.conditions, style: theme.textTheme.bodyMedium),
          ),

          _Section(
            title: 'Easily confused with',
            child: Text(info.confusableWith, style: theme.textTheme.bodyMedium),
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
                      'Identification guidance only. This app does not '
                      'recommend treatments — consult your local agricultural '
                      'extension officer before applying anything.',
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
