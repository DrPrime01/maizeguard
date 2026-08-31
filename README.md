# MaizeGuard

Offline-first Android app for detecting maize leaf disease on-device and mapping
where each observation was made.

Final-year B.Sc. Computer Science project — Gabriel Shoyombo, Miva Open
University. Built to PRD Rev. 2, derived from Chapters 1–3 of *"Design and
Implementation of a Mobile-Based Deep Learning System for Early Detection and
Geospatial Mapping of Maize Diseases"*.

**The workflow:** camera → MobileNetV2/TFLite → disease + confidence → GPS →
local record → map → Firebase sync.

## Supported classes

Maize Streak Virus · Common Rust · Grey Leaf Spot · Healthy

Four labels, fixed. Any other maize disease is out of scope and may be
misclassified as one of these — see `docs/acceptance-tests.md` (AT-11).

## Current state

| Area | State |
|---|---|
| App shell, navigation, auth | Working |
| Capture → inference → result → save | Working |
| GPS capture and graceful degradation | Working |
| Local SQLite persistence | Working |
| History with per-class filtering | Working |
| Disease catalogue | Working |
| Google Maps pins | Code complete — needs a Maps API key |
| Firebase auth + Firestore sync | Code complete — needs a Firebase project |
| Trained model | **Not yet trained.** Running on a stub classifier |

### About the stub classifier

`StubClassifier` derives a deterministic result from the image bytes: the same
photo always produces the same prediction. It exists so the whole pipeline
around inference could be built and demonstrated before training finished. Its
predictions are meaningless as diagnoses — it is scaffolding, not a model.

Swapping in the real model is one asset file plus one flag: see `ml/README.md`.

## Setup

### 1. Dependencies

```bash
flutter pub get
```

Note `tflite_flutter` pulls a ~54 MB archive; the first fetch is slow.

### 2. Google Maps key

Add the key to `android/local.properties` (gitignored, never committed):

```properties
MAPS_API_KEY=AIza...
```

Gradle injects it into the manifest at build time. Without it the app runs
normally and the Map screen renders with blank tiles.

**The key must be authorised for this app in Google Cloud Console**, or the
tiles stay blank and logcat reports `Authorization failure`:

1. Enable **Maps SDK for Android** on the project that owns the key.
2. The project needs an active **billing account** — Maps has a free monthly
   allowance but will not serve tiles without billing enabled.
3. If the key is restricted to Android apps, add this package and fingerprint
   pair (this is the local debug keystore):

   ```
   Package name: ng.edu.miva.maize_guard
   SHA-1:        B5:89:97:F5:6F:53:DD:B7:62:A0:FF:27:AF:69:51:16:DD:11:CF:41
   ```

   Get the SHA-1 for any other machine or a release keystore with:

   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore \
     -alias androiddebugkey -storepass android -keypass android | grep SHA1
   ```

The Maps SDK prints exactly what it wants on failure — check logcat for
`Google Android Maps SDK` and it will name the package/fingerprint pair.

### 3. Firebase

Firebase is **optional at build time**. `android/app/build.gradle.kts` applies
the google-services plugin only when `android/app/google-services.json` exists,
so the project builds and runs with no Firebase at all. Until it is configured
the app runs in **local mode**: a device-local account with sync disabled.
Everything offline still works — that is the architecture, not a workaround.

#### Option A — download the config directly (no CLI)

The fastest route, and it avoids the CLI entirely:

1. Firebase Console → your project → **Add app → Android**.
2. Package name: `ng.edu.miva.maize_guard`.
3. Add the debug SHA-1 above (needed for Google Sign-In; optional for
   email/password).
4. Download **`google-services.json`** and place it at `android/app/google-services.json`.
5. Authentication → Sign-in method → enable **Email/Password**.
6. Rebuild. Gradle logs `Firebase: google-services.json found, Firebase enabled.`

`main()` calls `Firebase.initializeApp()` with no arguments, which reads
`google-services.json` on Android — so `firebase_options.dart` is not required.

#### Option B — the CLI

```bash
firebase login --reauth   # required: the cached token expires and silently 401s
flutterfire configure --project=<your-project-id>
```

**If `flutterfire configure` reports "Found 0 Firebase projects"**, the Firebase
CLI token has expired. `firebase login:list` still shows the account because it
reads cached state, while every real API call returns 401. `flutterfire` shells
out to `firebase projects:list --json`, so it inherits the failure. Fix it with
`firebase login --reauth` — this needs an interactive browser sign-in.

#### Security rules

```bash
firebase deploy --only firestore:rules
```

### 4. Run

```bash
flutter emulators --launch Medium_Phone_API_36.0
flutter run -d emulator-5554
```

## Architecture

Local-first. Nothing in the detect path touches the network.

```
lib/
  app/        router, theme, Riverpod providers
  core/       configuration and thresholds
  domain/     models and the disease catalogue
  ml/         classifier interface, TFLite + stub implementations, preprocessing
  data/       sqflite database, DAOs, Firestore source, repository
  services/   location, connectivity, sync, auth, image storage
  features/   auth, home, detect, map, history, disease, settings
ml/           Colab training notebook
docs/         acceptance-test matrix
```

The load-bearing seam is `DiseaseClassifier` (`lib/ml/classifier.dart`).
`StubClassifier` and `TfliteClassifier` implement it identically, so everything
downstream — persistence, GPS, map, sync — was built and tested against a stable
interface before a model existed.

The local SQLite database is the source of truth. Firestore is a sync target,
not a cache in front of it, which is what lets history and the map work with no
connectivity.

## Testing

```bash
flutter analyze
flutter test
```

See `docs/acceptance-tests.md` for the AT-01 … AT-11 matrix and the manual
walkthrough.

## Toolchain notes

**Kotlin is pinned to 2.3.0** in `android/settings.gradle.kts`, overriding the
2.1.0 that Flutter 3.35.3's template generates. Both are required:

- `firebase-auth` 24.2.0 ships Kotlin metadata 2.3.0, which a 2.1.0 compiler
  rejects outright.
- `google_maps_flutter_android`'s generated `Messages.kt` crashes the 2.1.0 FIR
  frontend with `source must not be null`.

If you regenerate the Android folder, reapply this bump or the build fails on
both plugins.

## Known deviations from the PRD

1. **PRD §8 assumes PlantVillage supplies all four classes. It does not** — there
   is no Maize Streak Virus in PlantVillage. MSV is sourced from the CCMT
   (Ghana) dataset instead. See `ml/README.md`.
2. **Confidence threshold defaults to 70%, not the 95% quoted in PRD §9.2.**
   That figure is an example in the source chapters, and PRD §20 already flags
   that the real value must be justified from validation results. The notebook
   produces a threshold sweep for exactly that purpose. The value is adjustable
   in Settings and recorded per-scan.
3. **Images are not uploaded** — Firestore receives metadata only. Cloud Storage
   requires a billing-enabled plan on new Firebase projects, and the PRD's
   requirements (FR-08/FR-10) are satisfied without it.
# maizeguard
