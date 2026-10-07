# WatchGuy Implementation Plan

Each milestone is independently testable. Later milestones build on the contracts from earlier ones; they do not require every cloud credential to be present. Missing credentials degrade to an explicit unavailable state.

## M1 — Foundation

Deliverables: Flutter app, Riverpod, GoRouter, dark theme, environment loader, logging, typed errors, repository selection (`firebase` vs `local`).

Test: `flutter analyze` is clean. `flutter test` runs the config parser. App boots to the splash route on Android and iOS project targets.

## M2 — Authentication and mode selection

Deliverables: email/password sign-in and registration, password reset, email verification gate, Google sign-in, Apple sign-in on iOS, persistent session, organization creation, mode chooser, remembered mode, sign-out.

Test: auth state machine unit tests (signed out, unverified, needs organization, ready). Widget test covers mode selection. With Firebase dart-defines, a real account can sign in. Without them, local accounts exercise the same screens.

## M3 — Dashboard shell with live organization data

Deliverables: home summary, camera grid, incident timeline filters, settings, empty states. Data comes from the organization store (Firestore when configured, local store otherwise).

Test: summary math (online, offline, alert counts) and risk-priority ordering. Widget tests for an empty organization and a high-risk card.

## M4 — Camera mode preview

Deliverables: permission handling, full-screen preview, flip camera, wakelock, dimmed monitoring chrome, battery and connectivity indicators, start/stop monitoring.

Test: permission-denied and camera-unavailable states render. On a device or simulator with a camera, the preview starts. Analyzer covers both platform projects (`flutter build apk --debug` / `flutter build ios --debug --no-codesign` when the toolchains allow).

## M5 — QR pairing

Deliverables: dashboard creates a single-use expiring token, QR display, camera scans and confirms, name and location setup, camera document created.

Test: token expiry, single-use rejection, malformed QR, and successful claim. Secrets are stored only as hashes.

## M6 — Presence

Deliverables: coalesced heartbeats, online/offline derivation, battery, charging, AI and monitoring flags on the camera card.

Test: stale heartbeat becomes offline; a fresh heartbeat becomes online; unchanged heartbeats do not rewrite within the quiet window.

## M7 — On-demand live view

Deliverables: watch-live session document, publisher/subscriber token client, LiveKit room lifecycle, grid that stays on thumbnails, quality drop when leaving the detail view.

Test: session state machine (requested, publishing, active, closed). Token client refuses to run without a configured endpoint and never reads a LiveKit secret from the app.

## M8 — Local detection, tracking, zones

Deliverables: `ObjectDetector`, motion detector, IoU tracker, normalized polygon zones, zone editor, schedule context, obstruction heuristic.

Test: point-in-polygon, zone enter/leave, track id stability, loitering timer, ignored-area suppression. Detector tests use a fake detector. YOLO26n loads when `assets/models/yolo26n.tflite` is added.

## M9 — Circular recording and incidents

Deliverables: segment buffer, pre/post roll manifest, thumbnail, incident aggregate, review actions, retention delete, local wipe.

Test: buffer keeps only the configured pre-roll; incident clip covers pre-event and post-event windows; status transitions; review classification.

## M10 — Gemini pipeline and fused risk

Deliverables: adaptive sampler driven by policy (Remote Config when available), compact scene state, structured response parser, prompt constraints, `EventRiskEngine`.

Test: quiet vs person vs motion vs incident intervals; malformed Gemini payloads are rejected; cloud failure leaves local risk intact; fused scores hit the documented bands; copy never requires a forbidden label.

## M11 — Offline queue and notifications

Deliverables: outbox for metadata and media, retry with backoff, FCM token registration, high/critical notification payload that opens the incident.

Test: network-down enqueue, reconnect flush, upload failure retains the job, normal risk does not notify, high risk does.

## M12 — Hardening and release prep

Deliverables: security rules review, data-saver profiles, thermal governor, crash and permission edge states, Android and iOS release configuration notes, `.env.example`.

Test: full `flutter test` and `flutter analyze`. Release builds are configured; signing and real API keys remain outside git.

## V1 traceability

| Done criterion | Milestone |
| --- | --- |
| Account create/login | M2 |
| Dashboard mode | M3 |
| Second phone, camera mode | M4 |
| QR pairing | M5 |
| Camera online on dashboard | M6 |
| Live preview | M4 |
| People detection | M8 |
| Live video request and LiveKit | M7 |
| Adaptive Gemini analysis and live descriptions | M10 |
| Restricted zone and zone event | M8, M10 |
| Rolling buffer and incident clip | M9 |
| Risk engine opens an incident | M9, M10 |
| Push alert and footage playback | M9, M11 |
| Local monitoring without internet, later sync | M11 |
| No Gemini or LiveKit secret in the app | M7, M10, M12 |

## Credential boundary

These values are required for production cloud features and are never committed:

- Firebase project configuration (dart-defines or platform files)
- `GEMINI_API_KEY` on the server
- `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL` on the server
- APNs / FCM sender configuration inside the Firebase project
- Android signing keystore and iOS distribution certificate

`config/dart_defines.example.json` lists every client-side variable. Server names live in `.env.example`.
