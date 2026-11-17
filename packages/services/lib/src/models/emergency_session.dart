import 'package:guardian_core/guardian_core.dart';
import 'package:meta/meta.dart';

/// Server-owned state of one emergency session, as seen by the device.
///
/// Note there is no client-controllable path to [SessionStatus.ended]: the
/// device may observe it but never write it.
@immutable
class EmergencySession {
  const EmergencySession({
    required this.id,
    required this.kind,
    required this.status,
    required this.startedAt,
    this.contactId,
    this.livekitRoom,
    this.endedBy,
    this.lastLat,
    this.lastLng,
    this.lastLocAt,
  });

  final String id;
  final SessionKind kind;
  final SessionStatus status;
  final DateTime startedAt;
  final String? contactId;
  final String? livekitRoom;
  final EndedBy? endedBy;
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastLocAt;

  EmergencySession copyWith({SessionStatus? status, EndedBy? endedBy}) {
    return EmergencySession(
      id: id,
      kind: kind,
      status: status ?? this.status,
      startedAt: startedAt,
      contactId: contactId,
      livekitRoom: livekitRoom,
      endedBy: endedBy ?? this.endedBy,
      lastLat: lastLat,
      lastLng: lastLng,
      lastLocAt: lastLocAt,
    );
  }

  static EmergencySession fromRow(Map<String, dynamic> row) {
    return EmergencySession(
      id: row['id'] as String,
      kind: SessionKind.fromWire(row['kind'] as String? ?? 'full'),
      status: SessionStatus.fromWire(row['status'] as String),
      startedAt: DateTime.parse(row['started_at'] as String),
      contactId: row['contact_id'] as String?,
      livekitRoom: row['livekit_room'] as String?,
      endedBy: EndedBy.fromWire(row['ended_by'] as String?),
      lastLat: (row['last_lat'] as num?)?.toDouble(),
      lastLng: (row['last_lng'] as num?)?.toDouble(),
      lastLocAt: row['last_loc_at'] == null
          ? null
          : DateTime.parse(row['last_loc_at'] as String),
    );
  }
}
