import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/models/disease_class.dart';

/// A labelled probability bar. Used on the result screen to show the full
/// ranking rather than only the winning class — seeing that the runner-up was
/// close is useful context for a borderline call.
class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({
    required this.diseaseClass,
    required this.probability,
    this.emphasised = false,
    super.key,
  });

  final DiseaseClass diseaseClass;
  final double probability;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  diseaseClass.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        emphasised ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Text(
                '${(probability * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: emphasised ? FontWeight.bold : FontWeight.normal,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: probability.clamp(0.0, 1.0),
              minHeight: emphasised ? 10 : 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(diseaseClass.colour),
            ),
          ),
        ],
      ),
    );
  }
}
