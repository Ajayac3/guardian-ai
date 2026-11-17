import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_core/guardian_core.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:guardian_shared/guardian_shared.dart';

import 'contacts_screen.dart';
import 'providers.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Shell-mode demo toggle when no backend is configured.
  bool _demoActive = false;
  StreamSubscription<TriggerEvent>? _triggerSub;

  @override
  void initState() {
    super.initState();
    final trigger = ref.read(triggerServiceProvider);
    if (trigger != null) {
      trigger.arm(const TriggerConfig());
      _triggerSub = trigger.events.listen((event) {
        if (event.kind == TriggerKind.cancelSoft) return;
        final kind = event.kind == TriggerKind.softAlert
            ? SessionKind.soft
            : SessionKind.full;
        ref.read(emergencyControllerProvider.notifier).start(kind);
      });
    }
  }

  @override
  void dispose() {
    _triggerSub?.cancel();
    super.dispose();
  }

  static const _disclosures = <String>[
    'Guardian AI cannot function after a complete device shutdown.',
    'Platform restrictions vary by operating system.',
    'Emergency streaming is NOT an emergency-service dispatch.',
    'Recording laws vary by region — consent is handled per region.',
  ];

  Future<void> _onSos() async {
    final configured = ref.read(backendConfiguredProvider);
    if (configured) {
      await ref
          .read(emergencyControllerProvider.notifier)
          .start(SessionKind.full);
    } else {
      setState(() => _demoActive = !_demoActive);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emergencyControllerProvider);
    final active = state.isActive || _demoActive;
    final api = ref.watch(accountApiProvider);
    final push = ref.watch(pushServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian AI'),
        actions: [
          if (api != null) ...[
            IconButton(
              icon: const Icon(Icons.contacts_outlined),
              tooltip: 'Emergency contacts',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ContactsScreen(api: api),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(api: api, push: push),
                ),
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          RecordingIndicator(active: active),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SosButton(
                      active: active,
                      busy: state.phase == EmergencyPhase.starting,
                      onTap: _onSos,
                    ),
                    const SizedBox(height: 24),
                    if (state.phase == EmergencyPhase.error)
                      Text(
                        state.error ?? 'Something went wrong.',
                        style: const TextStyle(
                          color: GuardianTheme.emergencyRed,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    if (state.viewerUrl != null)
                      _ViewerLink(url: state.viewerUrl!),
                    const SizedBox(height: 24),
                    Text(
                      'Before you rely on Guardian AI',
                      style: Theme.of(context).textTheme.titleMedium,
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? GuardianTheme.emergencyRed : GuardianTheme.seed,
        ),
        child: Center(
          child: busy
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  active ? 'ACTIVE' : 'SOS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ViewerLink extends StatelessWidget {
  const _ViewerLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('Share this link with your contact:'),
            const SizedBox(height: 6),
            SelectableText(url, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
