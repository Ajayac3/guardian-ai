import 'package:meta/meta.dart';

/// Everything the publisher needs to join the media room for a session.
/// Minted server-side by the `create-session` Edge function.
@immutable
class SessionToken {
  const SessionToken({
    required this.sessionId,
    required this.livekitUrl,
    required this.room,
    required this.publisherJwt,
    required this.viewerUrl,
  });

  final String sessionId;
  final String livekitUrl;
  final String room;
  final String publisherJwt;

  /// The shareable, account-less link the emergency contact opens.
  final String viewerUrl;
}
