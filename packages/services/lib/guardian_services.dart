/// Service interfaces and domain models.
///
/// These are pure Dart with no SDK imports. Managed implementations live in the
/// `guardian_services_*` packages and are bound to these interfaces in
/// `app/lib/bootstrap.dart`. Swapping to self-hosted infrastructure means adding
/// a new implementation package and rebinding — no consumer changes.
library;

export 'src/models/contact_ref.dart';
export 'src/models/emergency_session.dart';
export 'src/models/evidence_chunk.dart';
export 'src/models/geo_ping.dart';
export 'src/models/push_message.dart';
export 'src/models/session_token.dart';
export 'src/models/trigger_event.dart';

export 'src/crypto_service.dart';
export 'src/location_service.dart';
export 'src/offline_queue.dart';
export 'src/push_service.dart';
export 'src/session_service.dart';
export 'src/storage_service.dart';
export 'src/streaming_service.dart';
export 'src/trigger_service.dart';
