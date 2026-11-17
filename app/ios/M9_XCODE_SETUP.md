# M9 — iOS Xcode wiring (do on a Mac)

All the iOS source/config is committed; these steps wire it into the Xcode
project (they can't be done on Linux). Open `ios/Runner.xcworkspace`.

> ⚠️ **The Runner target will NOT compile until step 3 below is done.**
> `AppDelegate.swift` references `GuardianTriggerBridge`, which lives in a file
> that isn't yet a member of any target. Adding the four Swift files (and the
> widget extension) to their targets in Xcode is the required first build step —
> `flutter build ios` / the `ios-build.yml` CI job will fail until then.

## Runner (main app) target
1. **Signing & Capabilities** → add: Push Notifications, Background Modes
   (Audio, Location updates, Voice over IP, Remote notifications, Background
   processing), App Groups (`group.com.guardianai.guardian`), Keychain Sharing,
   Time Sensitive Notifications, Siri.
2. Set **Code Signing Entitlements** = `Runner/Runner.entitlements` (already in
   the repo) for Debug + Release.
3. Add to the target: `Runner/GuardianTriggerBridge.swift`,
   `GuardianIntents/TriggerEmergencyIntent.swift`, `GuardianIntents/AppShortcuts.swift`.
4. Confirm `Runner/PrivacyInfo.xcprivacy` is in “Copy Bundle Resources”.
5. `Info.plist` already has the usage strings, `UIBackgroundModes`,
   `BGTaskSchedulerPermittedIdentifiers`, and the `guardianai` URL scheme.

## Widget Extension target (Control Center + lock screen)
1. File → New → Target → **Widget Extension** (name `GuardianControl`,
   include App Intents). Set its iOS deployment target to 18.0.
2. Replace its sources with `GuardianControl/GuardianControlWidget.swift`.
3. Add the **same App Group** (`group.com.guardianai.guardian`) to the
   extension's entitlements.

## Firebase (APNs)
1. Add `GoogleService-Info.plist` to the Runner target.
2. Upload the APNs **.p8** auth key to Firebase Cloud Messaging.

## Build
`flutter build ios --no-codesign` (CI: `.github/workflows/ios-build.yml`).
Requires the Apple Developer Program for signing, real push, and submission.
