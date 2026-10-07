# WatchGuy Architecture

WatchGuy turns ordinary phones into an organization-scoped security system. One Flutter codebase runs in two modes: a phone acting as a camera, and a phone acting as the dashboard that watches many cameras. Local intelligence does the expensive work. The cloud carries compact state, incident media, and on-demand live video.

## 1. System architecture

```
Camera phone                         Trusted backend                    Dashboard phone
---------------------------          ---------------------------        ---------------------------
Camera preview (24–30 fps)           Firebase Auth                      Auth session
Motion + object detection            App Check                          Camera grid + presence
Object tracking + zones              Firestore                          Incident timeline
Local risk rules                     Cloud Storage                      On-demand LiveKit view
10s circular video buffer            Cloud Functions / Cloud Run        Alert acknowledgement
Adaptive frame sampler               Gemini API (server key)            Zone editor
LiveKit publisher (on demand)        LiveKit token service              FCM receiver
Offline outbox                       FCM sender
```

Responsibilities are split on purpose:

| Layer | Owns | Must not own |
| --- | --- | --- |
| Camera phone | Capture, local detection, tracking, zones, rolling video, final risk decision when cloud AI is down | Gemini or LiveKit secrets, continuous cloud upload |
| Cloud | Identity, organization ACL, pairing validation, Gemini calls, LiveKit credentials, incident metadata, push | Per-frame detection that the phone can do |
| Dashboard phone | Monitoring UX, live view requests, review decisions | Inference, recording, privileged token minting |

Internet is optional for monitoring. It is required for cross-phone sync, Gemini interpretation, push alerts, and live view.

## 2. Mobile architecture

Feature-first clean architecture. Each feature has `domain` (entities, repository contracts, pure logic), `data` (Firestore, local files, HTTP), and `presentation` (Riverpod, GoRouter screens).

```
lib/
  app/            bootstrap, router, root widget
  core/           config, theme, errors, logging, networking, security
  features/
    auth/
    organization/
    dashboard/
    camera/
    pairing/
    zones/
    ai/           local detectors, Gemini client, risk engine
    live_stream/
    incidents/
    settings/
```

State management is Riverpod. Navigation is GoRouter. The last chosen mode (`camera` or `dashboard`) is persisted and restored after authentication.

Heavy work stays off the UI isolate:

- Camera frames are sampled, not all forwarded to Dart.
- Detection, tracking, motion scoring, JPEG encoding, and risk evaluation run through `CameraMonitor`, which drops frames when the previous pass is still running.
- A later native path (LiteRT on Android, Core ML on iOS) plugs in behind `ObjectDetector` without changing the monitor.

### Runtime modes

`AppConfig.backend` selects the data plane:

- `firebase` when `FIREBASE_PROJECT_ID` and the other Firebase dart-defines are present.
- `local` otherwise. The same repositories run against an on-device JSON store so the product is usable before a Firebase project is attached. Cross-phone sync, push, Gemini, and LiveKit require the Firebase/backend configuration. The UI says so instead of pretending those services are connected.

## 3. AI architecture

Three cooperating layers. Gemini is never the detector of record.

```
Frame
  → MotionDetector          (frame difference, obstruction heuristic)
  → ObjectDetector          (YOLO26n via LiteRT/TFLite or Core ML; motion blobs if no model asset)
  → ObjectTracker           (IoU association, stable track ids)
  → ZoneDetector            (normalized polygons)
  → ActivitySampler         (adaptive Gemini cadence)
  → LocalRiskEngine         (rules + schedule)
  → GeminiSceneInterpreter  (semantic update, skipped when offline)
  → EventRiskEngine         (fused score, incident decision)
```

### Models

The shipping detector interface is `ObjectDetector`. The default implementation is `YoloObjectDetector`, which loads `assets/models/yolo26n.tflite` when that file is present and runs LiteRT/TFLite off the UI isolate. iOS can later swap in a Core ML `.mlmodel` through the same interface. Until a converted YOLO26n asset is added, `MotionBlobDetector` supplies person-sized motion regions so tracking, zones, and incidents still run. Replacing the model does not change risk or incident code.

### Adaptive sampling

Rates live in `AiSamplingPolicy`, seeded by defaults and overridable through Firebase Remote Config (`ai_sample_quiet_seconds`, `ai_sample_person_seconds`, `ai_sample_motion_seconds`, `ai_sample_incident_seconds`):

| Scene | Default |
| --- | --- |
| Quiet | 1 frame / 2 s |
| Person visible | 1 frame / 1 s |
| Increased motion | 2 frames / 1 s |
| Potential incident | temporarily higher, capped by the policy |

Frames sent upstream are resized and JPEG-compressed. Full-rate video is only the local preview and the local recording buffer.

### Scene state

Each monitored camera keeps one compact `SceneState`. Gemini receives the newest sample plus that state, not a replay of history. The model returns structured JSON (`GeminiSceneUpdate`) and the phone merges it into the state. Descriptions are limited to observable behavior. The prompt forbids appearance-based labels such as criminal, evil, malicious, dangerous, or guilty.

### Risk fusion

`EventRiskEngine` adds local evidence and the Gemini delta, then clamps to 0–100. Default bands, also remote-configurable:

| Score | Level |
| --- | --- |
| 0–24 | normal |
| 25–44 | low |
| 45–64 | medium |
| 65–84 | high |
| 85–100 | critical |

Illustrative local contributions (each configurable on `SecurityRule`):

- Person present: small
- Person inside a restricted zone: moderate
- After-hours presence: moderate
- Rapid motion or repeated entrance interaction: moderate
- Gemini requests human review or `preserve_recording`: large

An incident is opened when the fused level reaches the configured threshold (default `high`) or when Gemini sets `preserve_recording` on an elevated score. Normal activity does not notify anyone.

## 4. Recording architecture

`CircularVideoBuffer` records short local segments (default 5 seconds) with the camera plugin and retains enough of them to cover a 10 second pre-roll. Segments are ordinary camera recordings, independent of Gemini's sample rate.

On incident:

1. Freeze the pre-roll segments.
2. Keep recording through the event and about 20 seconds after.
3. Write a clip manifest plus a thumbnail.
4. Create a local `Incident`.
5. Enqueue metadata and media for upload.

Nothing in the rolling buffer is uploaded unless it belongs to an incident. Continuous cloud recording is intentionally absent.

Playback walks the manifest in order so the operator sees one continuous clip. A later native concat step can flatten the manifest into a single file without changing the incident contract.

## 5. Backend architecture

Cloud Functions (see `functions/`) are the only component that sees Gemini and LiveKit secrets.

| Endpoint | Purpose |
| --- | --- |
| `createPairingToken` | Owner/admin mints a single-use token. Stores a hash, not the raw secret, with a short TTL. |
| `claimPairingToken` | Authenticated camera phone redeems the token once. Creates `CameraDevice`. |
| `issueLiveKitToken` | Short-lived publisher or subscriber grant for one room. |
| `analyzeScene` | Auth + App Check, then Gemini. Returns the structured scene update. |
| `signIncidentMedia` | Time-limited read/write URL after an ACL check. |
| `onIncidentNotify` | Sends FCM only for high and critical incidents. |

The phone calls these with the Firebase ID token. Privileged fields (role, risk override, token redemption, room grants) are ignored if a client writes them directly; Firestore rules deny those writes.

Firebase products in use: Authentication, Cloud Firestore, Cloud Messaging, Crashlytics, App Check, Remote Config, Storage.

## 6. Firestore data model

Collections stay shallow so list queries stay indexed.

```
users/{userId}
organizations/{organizationId}
organizations/{organizationId}/members/{memberId}
organizations/{organizationId}/cameras/{cameraId}
organizations/{organizationId}/incidents/{incidentId}
organizations/{organizationId}/zones/{zoneId}
organizations/{organizationId}/rules/{ruleId}
organizations/{organizationId}/pairingTokens/{tokenId}
organizations/{organizationId}/liveSessions/{sessionId}
```

`DeviceHeartbeat` is a map on the camera document (`heartbeat`), not a high-volume subcollection. The phone writes it on a slow cadence and on meaningful changes.

### Roles

`OrganizationMember.role` is one of `owner`, `admin`, `securityOperator`, `viewer`.

V1 enforcement:

- Owner and admin: pairing, zones, rules, retention, membership.
- Security operator: acknowledge alerts, classify incidents, watch live.
- Viewer: read cameras and incidents.

The member document and rules exist now so additional operators can join an organization without a schema change.

### Camera presence

A camera is **online** when `heartbeat.monitoredAt` is newer than the presence window (default 45 seconds) and `heartbeat.operationalState` is not `offline`. The dashboard derives this from the snapshot. It does not require a second write to mark a device offline; the window expires on its own. The camera also writes an explicit offline heartbeat when monitoring stops.

### Incident

Fields match the product contract: identity, organization, camera, event window, risk, description, observations, confidence, status (`detected` → `recording` → `processing` → `ready` → `notified` → `reviewed` or `dismissed`), review state (`unreviewed`, `confirmed`, `falseAlarm`, `unsure`), media URLs, and `createdByEngine`.

### Zones

Polygons are lists of `{x, y}` with both axes in `[0, 1]` relative to the camera frame. They are never stored as screen pixels. Types: `restricted`, `entrance`, `exit`, `watchArea`, `ignoredArea`.

### Pairing token

```
tokenId, secretHash, organizationId, createdBy, expiresAt, consumedAt, consumedByDeviceId
```

The QR payload is versioned JSON: `{v, org, tid, secret, exp}`. It contains no password, refresh token, or API key. Default lifetime is 10 minutes. Claiming twice fails.

## 7. LiveKit flow

Live video is on demand.

1. Dashboard writes `liveSessions/{sessionId}` with `cameraId`, `requestedBy`, `state: requested`.
2. The camera, already monitoring, sees the request and asks `issueLiveKitToken` for a publisher grant.
3. The dashboard asks for a subscriber grant on the same room (`org_{orgId}_cam_{cameraId}`).
4. The camera publishes. Grid tiles stay on the last thumbnail or a low-rate preview; only the focused camera is allowed a high-quality track.
5. When the viewer leaves, the session is closed and the camera stops publishing.

Target quality: thumbnails are still images; a single live view starts at 720p; 1080p is a later profile. Data saver mode caps resolution and frame rate. The Flutter app never contains the LiveKit API secret. If the token endpoint is not configured, the session UI reports that live view is unavailable and local monitoring continues.

## 8. Gemini flow

1. `ActivitySampler` decides a frame is due.
2. The phone downscales and compresses it, attaches the compact scene state, counts, zone flags, motion score, and schedule context.
3. `analyzeScene` calls Gemini with the server API key and a schema-constrained prompt.
4. The phone validates the JSON before it can affect risk or copy.
5. On timeout, parse failure, or offline, `GeminiSceneInterpreter` records `cloudOffline`. Local rules still score the scene. The camera UI shows **AI CLOUD OFFLINE** while monitoring stays active.

There is one logical scene state per actively monitored camera. Historical narrative is not resent.

## 9. Security model

- Secrets live in Cloud Functions environment variables or Secret Manager. `.env.example` lists names only.
- Firebase App Check is required on callable functions in production.
- Firestore and Storage rules scope every read and write to organization membership.
- Pairing secrets are hashed at rest. Comparison uses the hash. Tokens expire and are single-use.
- LiveKit grants are short-lived and room-scoped.
- Media URLs are signed and expire.
- Client-supplied `role`, `riskScore` overrides, and `consumedAt` are not honored from the device.
- Rate limits on `analyzeScene`, `createPairingToken`, and `issueLiveKitToken` sit in the functions layer.
- Transport is HTTPS only.
- Crashlytics is initialized only after Firebase configuration exists.

## 10. Offline behavior

Camera mode with no network still:

- shows the camera preview
- runs motion detection, tracking, zones, and local risk
- maintains the circular buffer
- opens incidents and stores clips on disk
- appends jobs to the outbox (`incident.metadata`, `incident.media`, `heartbeat`)

When connectivity returns, `SyncWorker` drains the outbox in order, retries uploads with backoff, and only then marks the incident `ready` / `notified`. A failed upload stays queued. The dashboard shows the last known heartbeat and an offline badge rather than a blank card.

Dashboard mode is read-mostly. It can classify incidents locally and queue the review write.

## 11. Bandwidth, battery, and thermals

- No continuous raw upload.
- Gemini frames are small and infrequent.
- Heartbeats are coalesced.
- LiveKit runs only while someone is watching.
- Data saver profiles: `lowData`, `balanced`, `highQuality`.
- `ThermalGovernor` lowers detector cadence and capture analysis resolution when the platform reports a serious thermal state, and surfaces a warning. It does not stop monitoring.
- Monitoring holds a wakelock and offers a dimmed preview. iOS capture is specified as foreground-only. Android foreground-service publishing is a later milestone, not a half-working background path in this version.

## 12. Deployment

```
Flutter app (Android + iOS)
  dart-defines for Firebase options and the functions region
Firebase project
  Auth providers: email/password, Google, Apple
  Firestore + indexes + rules
  Storage + rules
  Cloud Messaging
  App Check (Play Integrity, App Attest)
  Remote Config defaults
Cloud Functions
  GEMINI_API_KEY, LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_URL
LiveKit Cloud or self-hosted LiveKit
  room per watched camera
```

Release builds use the Flutter toolchains already generated under `android/` and `ios/`. Signing keys, `GoogleService-Info.plist`, and `google-services.json` are local files and are gitignored when they contain real project values. Sample placeholders document the expected shape without real credentials.

## 13. Privacy

- Default retention is configurable per organization (`incidentRetentionDays`).
- Operators can delete an incident, its video, or disable a camera.
- Camera settings can wipe the local recording directory.
- Only incident clips leave the device.
- AI copy describes actions and locations, not identity or moral character.
