# Acceptance test matrix

Maps every acceptance test in PRD §18 to how it is exercised in this build.

Legend for **Status**:
- `automated` — covered by `flutter test`
- `verified` — walked through on the API 36 emulator and confirmed working
  (see `docs/screenshots/`)
- `manual` — walkthrough defined, not yet run
- `blocked` — needs a credential or artefact that is not in place yet

| ID | Test | How it is exercised | Status |
|---|---|---|---|
| AT-01 | Offline scan | Put the emulator in airplane mode, capture a leaf, confirm a class and confidence appear. Inference runs through `TfliteClassifier`/`StubClassifier`, neither of which touches the network. | manual |
| AT-02 | Prediction | Result screen shows the predicted class and confidence, plus the full four-class ranking. `Prediction.label` / `.confidence` covered in `test/prediction_test.dart`. **Verified:** *Healthy 83.7%*, ranking Healthy 83.7 / Rust 13.9 / MSV 1.3 / GLS 1.1 summing to 100%. | automated + verified |
| AT-03 | Low confidence | `Prediction.isAcceptedAt` boundary cases in `test/prediction_test.dart`. In-app: a below-threshold result shows the red low-confidence panel, makes **Retake** the primary action, and only offers saving as *unconfirmed*. | automated + manual |
| AT-04 | GPS | Accepted observation carries latitude/longitude when permission and a fix are available. A missing fix stores the record without coordinates rather than discarding it — `test/scan_test.dart`. **Verified (degraded path):** permission granted, no fix arrived within the timeout, result screen said *"No GPS fix — saved without coordinates"* and the save still succeeded. The coordinate-present path still needs a device with a real fix. | automated + partly verified |
| AT-05 | Local save | With no network, save a scan and confirm it appears in History and on the Map after the flow completes. Persistence is unconditional and happens before any upload attempt. **Verified:** row written to `maize_guard.db`, image stored at `app_flutter/scan_images/<scanId>.jpg`, dashboard showed *1 Observation / 1 Pending sync*. Airplane-mode repeat still to run. | partly verified |
| AT-06 | Sync | Restore connectivity; `SyncService` sweeps on the connectivity event and the record flips `pending` → `synced`. Verify the document under `users/{uid}/scans/{scanId}` in the Firestore console. | blocked — needs Firebase project |
| AT-07 | Map | Saved observation appears as a pin at its recorded coordinates, coloured by class. Pins are read from the local database, so they render without a network (tiles still need one). | blocked — needs Maps API key |
| AT-08 | History | Signed-in user retrieves their observations, filterable by class. Every query is scoped by `currentUserIdProvider`. **Verified:** saved scan appeared in *Recent observations* as `Healthy · 84% · no GPS` with a pending-sync indicator. | verified |
| AT-09 | Security | `firestore.rules` restricts `users/{userId}/**` to `request.auth.uid == userId`. Verify with the Rules Playground, or by signing in as a second user and attempting to read the first user's path. | blocked — needs Firebase project |
| AT-10 | Performance | Every scan records `inferenceMs`; the mean is shown in Settings → *Average inference time*. **Verified:** 334 ms recorded and surfaced on the dashboard — but this is the **stub**, so the number measures scaffolding, not the model. Re-measure after installing the trained TFLite. | verified (stub) |
| AT-11 | Scope conformance | `test/disease_class_test.dart` asserts exactly four labels in the PRD-specified order and that `labels.txt` matches the enum. `TfliteClassifier.load()` refuses a model whose output tensor is not 4-wide. `firestore.rules` rejects any other class server-side. | automated |

## Running the automated portion

```bash
flutter test
```

## Manual walkthrough on the emulator

```bash
flutter emulators --launch Medium_Phone_API_36.0
flutter run -d emulator-5554
```

1. Sign in (any email plus a 6+ character password while in local mode).
2. **Scan a leaf** → the emulator camera opens → capture.
3. Confirm the result screen shows a class, a confidence, the four-class
   ranking, and the location card.
4. Save, then check Home, History and Map.
5. For AT-01/AT-05, enable airplane mode before step 2 and confirm the flow is
   unchanged.

Note: the emulator's camera is a synthetic scene, not a maize leaf. It exercises
the capture → inference → save pipeline, but the predicted class is meaningless
until you test on a real device with real leaves.


## Emulator run of 2026-08-31

First end-to-end run on `Medium_Phone_API_36.0` (Android 16, API 36), debug build,
stub classifier, no Firebase and no Maps key configured.

Confirmed working: sign-in and auth-gated routing, dashboard, bottom-tab
navigation, disease catalogue, camera capture via `image_picker`, on-device
preprocessing and inference, the four-class result screen, location permission
flow with graceful no-fix degradation, local persistence of both the database
row and the image file, and dashboard statistics.

Zero Dart exceptions across the run.

Two notes from the run:
- One transient ANR occurred while driving the UI with rapid `adb input` events
  against a cold debug build. The app recovered on its own and no Dart error was
  logged. Not reproduced under normal touch interaction.
- `flutter run` exits when its stdin closes, which kills the app. For scripted
  driving, launch the installed APK with
  `adb shell am start -n ng.edu.miva.maize_guard/.MainActivity` instead.
