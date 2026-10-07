# WatchGuy

WatchGuy is a Flutter app that turns phones into AI security cameras and gives another phone a dashboard for all of them. One codebase runs on Android and iOS.

Local mode works before any cloud project exists. Cross-phone sync, Gemini interpretation, LiveKit, and push alerts start when the placeholders in `config/dart_defines.example.json` and `.env.example` are filled in. The mobile app never contains a Gemini or LiveKit secret.

## Run

The Flutter SDK used for this workspace is in `.tooling/flutter` and is not part of the app.

```bash
.tooling/flutter/bin/flutter pub get
.tooling/flutter/bin/flutter test
.tooling/flutter/bin/flutter run
```

To attach Firebase:

```bash
cp config/dart_defines.example.json config/dart_defines.json
.tooling/flutter/bin/flutter run --dart-define-from-file=config/dart_defines.json
```

`config/dart_defines.json` is gitignored. Leave the values empty to stay in local mode.

## Cloud services

`functions/` is the trusted API:

- create and claim single-use pairing tokens
- issue short-lived LiveKit tokens
- hold a Gemini Live session and accept sampled frames
- send a push only for high and critical incidents

Copy `.env.example` to `functions/.env` for the emulator. Real keys stay in Secret Manager or the functions environment.

Firestore and Storage rules are in `firestore.rules` and `storage.rules`.

## On-device detection

`ObjectDetector` is the model boundary. `MotionBlobDetector` runs without a download. The YOLO26n path uses the official Ultralytics Flutter plugin (`ultralytics_yolo`), which runs LiteRT on Android and Core ML on iOS and downloads `yolo26n` on first use. That plugin is AGPL-3.0. The rest of WatchGuy talks only to `ObjectDetector`, so the model can be replaced.

## What still needs a device and credentials

- A paired second phone showing online in the dashboard (Firebase)
- A LiveKit room for Watch live
- Gemini descriptions from the live session
- FCM delivery (the incident record and local notification path already exist)
- A release keystore and an Apple distribution certificate

See `ARCHITECTURE.md` and `IMPLEMENTATION_PLAN.md` for the system design and milestone map.
