import 'package:flutter/material.dart';
import 'package:guardian_shared/guardian_shared.dart';

import 'root_gate.dart';

class GuardianApp extends StatelessWidget {
  const GuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian AI',
      debugShowCheckedModeBanner: false,
      theme: GuardianTheme.light(),
      darkTheme: GuardianTheme.dark(),
      home: const RootGate(),
    );
  }
}
