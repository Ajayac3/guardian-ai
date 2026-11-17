# Skill: Trigger systems
How to add or tune an emergency trigger.

- All triggers normalize to `TriggerService.events` emitting `TriggerEvent`.
- Android: foreground service + openWakeWord TFLite. Swap the model by replacing
  the asset in `app/android/app/src/main/assets/wakeword/` and updating phrase ids.
- Backup triggers: SOS hold, volume-button pattern, shake (accelerometer).
- iOS: App Intents (Siri/Action Button), Control Center control, lock-screen widget.
- Target <300ms where the platform permits; gate with VAD to save battery.
