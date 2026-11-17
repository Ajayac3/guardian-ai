import 'package:meta/meta.dart';

/// A single location sample from the device during a session.
@immutable
class GeoPing {
  const GeoPing({
    required this.lat,
    required this.lng,
    required this.at,
    this.accuracyMeters,
    this.speedMps,
    this.heading,
  });

  final double lat;
  final double lng;
  final DateTime at;
  final double? accuracyMeters;
  final double? speedMps;
  final double? heading;

  factory GeoPing.fromJson(Map<String, dynamic> json) => GeoPing(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    at: DateTime.parse(json['at'] as String),
    accuracyMeters: (json['accuracy_m'] as num?)?.toDouble(),
    speedMps: (json['speed_mps'] as num?)?.toDouble(),
    heading: (json['heading'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'at': at.toUtc().toIso8601String(),
    if (accuracyMeters != null) 'accuracy_m': accuracyMeters,
    if (speedMps != null) 'speed_mps': speedMps,
    if (heading != null) 'heading': heading,
  };
}
