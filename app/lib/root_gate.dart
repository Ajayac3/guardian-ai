import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'providers.dart';

/// Decides the first screen: the shell/home in demo mode, otherwise onboarding
/// until the anti-stalking attestation is recorded, then home.
class RootGate extends ConsumerStatefulWidget {
  const RootGate({super.key});

  @override
  ConsumerState<RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<RootGate> {
  Future<bool>? _onboarded;
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(accountApiProvider);
    if (api == null || _completed) return const HomeScreen();

    _onboarded ??= api.isOnboarded();
    return FutureBuilder<bool>(
      future: _onboarded,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == true) return const HomeScreen();
        return OnboardingScreen(
          api: api,
          onCompleted: () => setState(() => _completed = true),
        );
      },
    );
  }
}
