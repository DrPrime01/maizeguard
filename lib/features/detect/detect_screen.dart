import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/app_config.dart';
import '../../ml/prediction.dart';
import '../../services/location_service.dart';
import '../shared/confidence_bar.dart';

enum _Stage { idle, classifying, result, error }

/// The core workflow (PRD §7.1): capture -> preprocess -> infer -> locate ->
/// review -> save.
///
/// Inference runs before the GPS request so the user sees a result as soon as
/// possible; the location attempt continues in the background and is folded in
/// when it lands. A slow satellite fix should not make the app feel slow.
class DetectScreen extends ConsumerStatefulWidget {
  const DetectScreen({super.key});

  @override
  ConsumerState<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends ConsumerState<DetectScreen> {
  final _picker = ImagePicker();

  _Stage _stage = _Stage.idle;
  File? _image;
  Prediction? _prediction;
  LocationResult? _location;
  bool _locating = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Start capture as soon as the screen opens — the user tapped "Scan",
    // making them tap again would be a pointless extra step.
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    setState(() {
      _error = null;
      _prediction = null;
      _location = null;
    });

    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        // Cap the long edge: the model only sees 224px, and full-resolution
        // frames cost decode time and storage for no accuracy gain.
        maxWidth: 1440,
        maxHeight: 1440,
        imageQuality: 90,
      );
      if (shot == null) {
        if (mounted && _stage == _Stage.idle) context.pop();
        return;
      }

      final file = File(shot.path);
      setState(() {
        _image = file;
        _stage = _Stage.classifying;
      });

      unawaited(_resolveLocation());

      final classifier = await ref.read(classifierReadyProvider.future);
      final prediction = await classifier.classify(file);

      if (!mounted) return;
      setState(() {
        _prediction = prediction;
        _stage = _Stage.result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _stage = _Stage.error;
      });
    }
  }

  Future<void> _resolveLocation() async {
    setState(() => _locating = true);
    final result = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;
    setState(() {
      _location = result;
      _locating = false;
    });
  }

  Future<void> _save({required double threshold}) async {
    final image = _image;
    final prediction = _prediction;
    final userId = ref.read(currentUserIdProvider);
    if (image == null || prediction == null || userId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(scanRepositoryProvider).saveObservation(
            userId: userId,
            capturedImage: image,
            prediction: prediction,
            threshold: threshold,
            location: _location ?? const LocationUnavailable('not requested'),
          );
      ref.read(observationRevisionProvider.notifier).bump();
      // Opportunistic upload; a failure here is not the user's problem — the
      // record is already safe on disk.
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Observation saved')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final thresholdAsync = ref.watch(confidenceThresholdProvider);
    final threshold =
        thresholdAsync.value ?? AppConfig.defaultConfidenceThreshold;

    return Scaffold(
      appBar: AppBar(title: const Text('Detect disease')),
      body: switch (_stage) {
        _Stage.idle => const Center(child: CircularProgressIndicator()),
        _Stage.classifying => _busyView(),
        _Stage.error => _errorView(),
        _Stage.result => _resultView(threshold),
      },
    );
  }

  Widget _busyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_image!, height: 220, fit: BoxFit.cover),
            ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('Analysing leaf on this device...'),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: _capture, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _resultView(double threshold) {
    final prediction = _prediction!;
    final accepted = prediction.isAcceptedAt(threshold);
    final theme = Theme.of(context);
    final ranked = prediction.ranked;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(_image!, height: 240, width: double.infinity,
              fit: BoxFit.cover),
        ),
        const SizedBox(height: 20),

        // Headline result.
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: prediction.label.colour.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(prediction.label.icon,
                  color: prediction.label.colour, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prediction.label.displayName,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    '${(prediction.confidence * 100).toStringAsFixed(1)}% confidence',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // FR-06 / AT-03: a below-threshold result is never presented as
        // reliable. Retake is the primary action; saving it anyway is possible
        // but explicitly marked unconfirmed.
        if (!accepted) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Low confidence',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'This result is below the ${(threshold * 100).toStringAsFixed(0)}% '
                  'threshold and should not be relied on. Retake the photo with '
                  'the leaf filling the frame, in even light.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        Text('All classes', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final entry in ranked)
          ConfidenceBar(
            diseaseClass: entry.label,
            probability: entry.probability,
            emphasised: entry.label == prediction.label,
          ),

        const SizedBox(height: 20),
        _locationCard(),

        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Inference time'),
            trailing: Text('${prediction.inferenceMs} ms',
                style: theme.textTheme.titleMedium),
          ),
        ),

        const SizedBox(height: 24),
        if (accepted)
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(threshold: threshold),
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save observation'),
          )
        else ...[
          FilledButton.icon(
            onPressed: _saving ? null : _capture,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Retake photo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saving ? null : () => _save(threshold: threshold),
            child: const Text('Save anyway as unconfirmed'),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: _saving ? null : _capture,
          child: const Text('Discard and capture again'),
        ),
      ],
    );
  }

  Widget _locationCard() {
    final location = _location;
    final (IconData icon, String title, String? subtitle) = switch (location) {
      LocationFix fix => (
          Icons.location_on,
          '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)}',
          'Accurate to about ${fix.accuracyMeters.toStringAsFixed(0)} m',
        ),
      LocationServiceDisabled() => (
          Icons.location_disabled,
          'Location services are off',
          'The observation will be saved without coordinates.',
        ),
      LocationPermissionDenied(permanently: final permanently) => (
          Icons.location_disabled,
          'Location permission denied',
          permanently
              ? 'Enable it in system settings to map observations.'
              : 'The observation will be saved without coordinates.',
        ),
      LocationUnavailable() => (
          Icons.location_searching,
          'No GPS fix',
          'The observation will be saved without coordinates.',
        ),
      null => (
          Icons.location_searching,
          _locating ? 'Getting location...' : 'Location pending',
          null,
        ),
    };

    return Card(
      child: ListTile(
        leading: _locating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
      ),
    );
  }
}
