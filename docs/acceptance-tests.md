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
| AT-06 | Sync | `SyncService` sweeps on connectivity and on manual retry; the record flips `pending` → `synced`. **Verified 2026-09-02:** write accepted at `users/{uid}/scans/{scanId}`, dashboard went to *All synced / Pending sync 0*, row icon changed to cloud-done. | verified |
| AT-07 | Map | Saved observation appears as a pin at its recorded coordinates, coloured by class. Pins are read from the local database. **Verified 2026-09-02:** amber MSV pin rendered at 7.37750, 3.94700 over live Ibadan street tiles, info window *"Maize Streak Virus - 93% - 2 Sep 2026"*, legend counting `MSV (1)`. Required the Firebase-auto-created Android key; a separately-created key in the same project was rejected regardless of restrictions. | verified |
| AT-08 | History | Signed-in user retrieves their observations, filterable by class. Every query is scoped by `currentUserIdProvider`. **Verified:** saved scan appeared in *Recent observations* as `Healthy · 84% · no GPS` with a pending-sync indicator. | verified |
| AT-09 | Security | `firestore.rules` restricts `users/{userId}/**` to `request.auth.uid == userId`, and rejects any `disease` outside the four labels. **Partly verified:** rules published; production-mode default denied writes until they were, and the owner's own write then succeeded. The cross-user denial still needs a second account to confirm explicitly. | partly verified |
| AT-10 | Performance | Every scan records `inferenceMs`; the mean is shown in Settings. **Verified with the trained MobileNetV2:** 2,335 ms and 4,737 ms end-to-end on the API 36 emulator (debug build, x86 translation, no GPU delegate). Covers file read + decode + 224x224 preprocessing + inference, not inference alone. Emulator figures are pessimistic - **re-measure on physical hardware in release mode before quoting in Chapter 4.** | verified (emulator) |
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


## Emulator run of 2026-09-02 — trained model

Re-run on `Medium_Phone_API_36.0` with the trained MobileNetV2 in place
(`kUseTrainedModel = true`), replacing the stub.

Confirmed working:

- The TFLite model loads from assets and passes the 4-output shape check at
  startup. Verified `Stored` (uncompressed) in the APK, so the interpreter can
  map it directly.
- Real on-device inference: predicted **Maize Streak Virus at 90.7%**, with the
  full four-class distribution (Rust 4.6, GLS 2.6, Healthy 2.0) summing to 100%.
- GPS attached at 7.37750, 3.94700 (±5 m) — AT-04's coordinate path, not just
  the degraded one.
- Observation persisted; dashboard advanced to 3 observations.
- Map legend counted the two GPS-tagged observations correctly by class.

**Latency caveat for Chapter 4:** the first inference measured 2,335 ms, and the
running mean across the three stored scans is 970 ms. Both are emulator numbers
from a debug build with no GPU delegate, and the metric spans preprocessing as
well as inference. They are an upper bound, not a representative field figure.


## Verified run of 2026-09-02 — full stack

Second end-to-end run on `Medium_Phone_API_36.0`, this time with the **trained
MobileNetV2 model**, **Firebase configured**, and a **working Maps key**.

Confirmed working end to end:

1. Firebase Auth registration (`FirebaseAuth: Notifying auth state listeners`),
   app leaving local mode.
2. Camera capture -> real TFLite inference: *Maize Streak Virus 93.5%*, four
   classes summing to 100%.
3. GPS fix attached: 7.37750, 3.94700, +/-5 m.
4. Local persistence, then Firestore sync to `users/{uid}/scans/{scanId}`.
5. Map rendering the observation as a class-coloured pin over live tiles.

### Configuration notes learned the hard way

* **The Maps key must be the one Firebase auto-creates** for the Android app
  (present in `google-services.json`). A separately-created key in the same
  project kept returning `Authorization failure` even with the API enabled and
  the correct package/SHA-1 restrictions applied.
* **Map tiles take ~20s and a camera movement on a cold emulator.** A blank map
  showing only the blue location dot is not necessarily a failure.
* Firestore must be **created as a database**, not merely have Authentication
  enabled. Before creation the error is *"Cloud Firestore API has not been used
  in project"*; after creation but before rules, *"Missing or insufficient
  permissions"*. The two are easy to confuse.

### Graceful-degradation evidence

Both failure states were observed and handled without data loss: the
observation persisted locally, the dashboard showed *"1 waiting to sync"* with a
retry control, and the record synced successfully once the backend was
corrected. This is direct evidence for FR-09 reliability.
