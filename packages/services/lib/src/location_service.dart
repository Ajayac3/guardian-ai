import 'models/geo_ping.dart';

abstract interface class LocationService {
  /// Ensures the needed permission is granted. [background] requests the
  /// background-location grant required for streaming with the screen off.
  Future<bool> ensurePermission({required bool background});

  /// A continuous location stream while a session is live.
  Stream<GeoPing> watch({Duration interval});

  Future<GeoPing> current();
}
