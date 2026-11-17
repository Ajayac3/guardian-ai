# Compliance

## Google Play
- Foreground service types `microphone|camera|location` require per-type
  declaration + a demo video + use-case justification on the Play Console.
- Owner-initiated only; persistent recording notification; privacy policy;
  Data Safety form; no covert/ambient recording. (Stalkerware policy.)

## Apple App Store
- No always-on wake-word; Action Button / Shortcut / Control Center / manual.
- Visible recording indicator (Guideline 2.5.14); background modes limited to
  declared uses; Privacy Manifest + nutrition labels mandatory; account deletion.

## User disclosures (spec §11) — surfaced in onboarding
- The app cannot function after complete device shutdown.
- Platform restrictions vary by OS.
- Emergency streaming is NOT emergency-service dispatch.
- Recording laws vary by region (region-aware consent).
