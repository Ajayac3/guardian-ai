import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_shared/guardian_shared.dart';

import 'account_api.dart';

const _disclosures = <String>[
  'Guardian AI cannot function after a complete device shutdown.',
  'Platform restrictions vary by operating system.',
  'Emergency streaming is NOT an emergency-service dispatch — call your local '
      'emergency number for life-threatening situations.',
  'Recording laws vary by region — by continuing you consent to recording and '
      'streaming during an emergency you start.',
];

const regions = <String>['US', 'CA', 'GB', 'EU', 'IN', 'AU', 'Other'];

/// One-time onboarding: surfaces the platform/compliance disclosures and
/// captures the anti-stalking attestation that gates session creation
/// (`create-session` rejects without `profiles.anti_stalking_attested_at`).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    required this.api,
    required this.onCompleted,
    super.key,
  });

  final AccountApi api;
  final VoidCallback onCompleted;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _consent = false;
  bool _attest = false;
  String _region = regions.first;
  bool _busy = false;
  String? _error;

  bool get _canContinue => _consent && _attest && !_busy;

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.attestAntiStalking(regionCode: _region);
      widget.onCompleted();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Guardian AI')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Before you begin',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ..._disclosures.map(
              (d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(d)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _region,
              decoration: const InputDecoration(
                labelText: 'Your region (for consent rules)',
              ),
              items: regions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _region = v ?? _region),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: const Text(
                'I understand and consent to recording and streaming during an '
                'emergency I start.',
              ),
            ),
            CheckboxListTile(
              value: _attest,
              onChanged: (v) => setState(() => _attest = v ?? false),
              title: const Text(
                'I attest I will use Guardian AI only for my own safety, never to '
                'track, monitor, or coerce another person.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: GuardianTheme.emergencyRed),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _canContinue ? _continue : null,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
