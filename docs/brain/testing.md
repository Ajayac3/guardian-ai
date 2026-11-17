# Testing strategy

| Layer | Tool | Where |
|---|---|---|
| Unit | flutter_test | Linux |
| Widget | flutter_test | Linux |
| Golden | alchemist | Linux |
| Integration (Dart) | integration_test + local Supabase + local LiveKit | Linux (AVD/chrome) |
| System/permissions/background | patrol | AVD on Linux |
| SQL/RLS | pgTAP / SQL asserts | Linux (local Supabase) |
| Viewer unit | vitest | Linux |
| Viewer e2e | Playwright (Chromium) | Linux |

Deferred to device/Mac: real FGS battery/SMS, iOS compile + App Intents/Action
Button/Control Center, Secure Enclave, real APNs.
