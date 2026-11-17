import 'package:geolocator/geolocator.dart';
import 'package:guardian_services/guardian_services.dart';

class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService();

  @override
  Future<bool> ensurePermission({required bool background}) async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    // Background streaming needs the "always" grant; whileInUse suffices for
    // foreground use with the Android foreground service active.
    if (background) {
      return permission == LocationPermission.always;
    }
    return true;
  }

  @override
  Stream<GeoPing> watch({Duration interval = const Duration(seconds: 5)}) {
    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
    return Geolocator.getPositionStream(
      locationSettings: settings,
    ).map(_toPing);
  }

  @override
  Future<GeoPing> current() async {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return _toPing(pos);
  }

  GeoPing _toPing(Position p) => GeoPing(
    lat: p.latitude,
    lng: p.longitude,
    at: p.timestamp,
    accuracyMeters: p.accuracy,
    speedMps: p.speed,
    heading: p.heading,
  );
}
