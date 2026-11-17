import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await initBackend();
  runApp(
    ProviderScope(
      overrides: [
        if (backend != null) ...[
          sessionServiceProvider.overrideWithValue(backend.session),
          streamingServiceProvider.overrideWithValue(backend.streaming),
          locationServiceProvider.overrideWithValue(backend.location),
          cryptoServiceProvider.overrideWithValue(backend.crypto),
          storageServiceProvider.overrideWithValue(backend.storage),
          foregroundSessionProvider.overrideWithValue(backend.foreground),
          triggerServiceProvider.overrideWithValue(backend.trigger),
          offlineQueueProvider.overrideWithValue(backend.offlineQueue),
          pushServiceProvider.overrideWithValue(backend.push),
          accountApiProvider.overrideWithValue(backend.account),
          backendConfiguredProvider.overrideWithValue(true),
          targetContactProvider.overrideWith((_) async => backend.contact),
        ],
      ],
      child: const GuardianApp(),
    ),
  );
}
