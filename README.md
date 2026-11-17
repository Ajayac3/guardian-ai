# GuardianAI

An emergency live-streaming safety app built with Flutter. A user in trouble streams audio, video and location to trusted contacts, who watch in a browser without installing anything.

## Layout
- `app/`: the Flutter app (Android and iOS)
- `packages/`: 19 packages (streaming, contacts, encryption, session control and others)
- `viewer/`: the no-install browser viewer
- `supabase/`: database migrations, row-level security rules and SQL tests
- `docs/brain/`: architecture, security, testing and decision notes

## Main ideas
- Live audio, video and GPS over WebRTC (LiveKit)
- Sessions controlled by the server, with SQL tests for the access rules
- Recordings encrypted on the device before upload

## Run
```
flutter pub get
cd app && flutter run
```
Copy `.env.example` and `app/android/app/google-services.example.json` and fill in your own keys; none are stored in this repository.

This is a cleaned public snapshot of a private working repository.
