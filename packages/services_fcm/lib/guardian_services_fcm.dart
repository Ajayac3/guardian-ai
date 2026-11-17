/// Firebase Cloud Messaging implementation of PushService.
///
/// Scaffolded in M0; implemented in M7. [FcmPushService] needs a configured
/// Firebase app; [NoopPushService] is bound when none is present so the app
/// still compiles and runs without `google-services.json`.
library;

export 'src/fcm_push_service.dart';
