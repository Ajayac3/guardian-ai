/// Lifecycle of an emergency session, mirrored exactly by the
/// `emergency_sessions.status` column in Supabase.
///
/// The device can move a session forward but can never reach [ended] —
/// only the server (verified contact / timeout / recovery) can. See
/// `docs/brain/security.md`.
enum SessionStatus {
  starting,
  active,
  lostConnection,
  ending,
  ended,
  cancelled;

  static SessionStatus fromWire(String value) => switch (value) {
    'starting' => SessionStatus.starting,
    'active' => SessionStatus.active,
    'lost_connection' => SessionStatus.lostConnection,
    'ending' => SessionStatus.ending,
    'ended' => SessionStatus.ended,
    'cancelled' => SessionStatus.cancelled,
    _ => throw ArgumentError('Unknown session status: $value'),
  };

  String get wire => switch (this) {
    SessionStatus.starting => 'starting',
    SessionStatus.active => 'active',
    SessionStatus.lostConnection => 'lost_connection',
    SessionStatus.ending => 'ending',
    SessionStatus.ended => 'ended',
    SessionStatus.cancelled => 'cancelled',
  };

  bool get isTerminal =>
      this == SessionStatus.ended || this == SessionStatus.cancelled;

  bool get isLive =>
      this == SessionStatus.starting ||
      this == SessionStatus.active ||
      this == SessionStatus.lostConnection;
}

/// "Help help help" (full) vs "Guardian watch me" (soft alert).
enum SessionKind {
  full,
  soft;

  static SessionKind fromWire(String value) =>
      value == 'soft' ? SessionKind.soft : SessionKind.full;

  String get wire => this == SessionKind.soft ? 'soft' : 'full';
}

/// Who ended a session. The device is deliberately absent from this list.
enum EndedBy {
  contact,
  serverTimeout,
  recovery,
  ownerCancelSoft;

  static EndedBy? fromWire(String? value) => switch (value) {
    'contact' => EndedBy.contact,
    'server_timeout' => EndedBy.serverTimeout,
    'recovery' => EndedBy.recovery,
    'owner_cancel_soft' => EndedBy.ownerCancelSoft,
    _ => null,
  };

  String get wire => switch (this) {
    EndedBy.contact => 'contact',
    EndedBy.serverTimeout => 'server_timeout',
    EndedBy.recovery => 'recovery',
    EndedBy.ownerCancelSoft => 'owner_cancel_soft',
  };
}
