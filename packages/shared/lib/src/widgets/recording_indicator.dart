import 'package:flutter/material.dart';

import '../theme.dart';

/// A non-dismissible, always-visible banner shown whenever the app is
/// recording/streaming. Required by both store policies and the spec's
/// privacy-first stance — the user must always know recording is active.
class RecordingIndicator extends StatelessWidget {
  const RecordingIndicator({
    super.key,
    required this.active,
    this.label = 'Recording — emergency session active',
  });

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    return Material(
      color: GuardianTheme.emergencyRed,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const _PulsingDot(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
