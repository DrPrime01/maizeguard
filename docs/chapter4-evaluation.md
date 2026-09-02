# Chapter 4 — System Evaluation and Results

Evaluation material for *"Design and Implementation of a Mobile-Based Deep
Learning System for Early Detection and Geospatial Mapping of Maize Diseases"*.

All figures below were produced by `ml/maize_guard_training.ipynb` and by
on-device testing of the MaizeGuard Android application. Raw artefacts:
`docs/model/metrics.json`, `docs/model/confusion_matrix.png`,
`docs/acceptance-tests.md`.

---

## 4.1 Dataset

The four-class label set (MSV, Common Rust, Grey Leaf Spot, Healthy) could not
be sourced from a single dataset. **PlantVillage contains no Maize Streak Virus
class** — its maize subset covers only Cercospora/Grey Leaf Spot, Common Rust,
Northern Leaf Blight and Healthy. MSV was therefore sourced from the CCMT crop
pest and disease dataset collected in Ghana, chosen over a larger Tanzanian
alternative because West African field conditions are the closer proxy for
South-West Nigeria.

| Class | Source | Train | Val | Test | Total |
|---|---|---:|---:|---:|---:|
| MSV | CCMT (Ghana) | 675 | 144 | 146 | 965 |
| Common Rust | PlantVillage | 834 | 178 | 180 | 1,192 |
| Grey Leaf Spot | PlantVillage | 359 | 76 | 78 | 513 |
| Healthy | PlantVillage | 813 | 174 | 175 | 1,162 |
| **Total** | | **2,681** | **572** | **579** | **3,832** |

Split 70/15/15, stratified per class, performed on **files before augmentation**
so no augmented variant of a training image can appear in the test set.

### Data-integrity controls

Three defects were found and corrected during preparation. Each is reported
because each would have inflated the results:

1. **Duplicate renderings.** The initial run drew on multiple PlantVillage
   renderings (colour, greyscale, segmented) of the same physical leaves. The
   same leaf therefore appeared in both training and test splits, which is
   test-set leakage. Restricting to a single rendering reduced the corpus from
   ~11,500 to 3,832 images and the epoch step count from 147 to 84.
2. **Corrupt images.** Several files were structurally invalid JPEGs that
   passed an extension check and then failed inside `model.fit` with
   `jpeg::Uncompress failed`. They were removed using the same TensorFlow
   decoder the training pipeline uses.
3. **Exact duplicates**, removed by MD5 content hash.

**Effect of correcting leakage:** test accuracy fell from 99.4% to 98.4%. The
lower figure is the honest one and is the figure reported throughout.

---

## 4.2 Model configuration

| Item | Value |
|---|---|
| Architecture | MobileNetV2, ImageNet weights, transfer learning |
| Input | 224 x 224 x 3, scaled to [-1, 1] |
| Head | GlobalAveragePooling -> Dropout(0.3) -> Dense(4, softmax) |
| Stage 1 | Base frozen, Adam 1e-3, up to 20 epochs |
| Stage 2 | Top third unfrozen (BatchNorm kept frozen), Adam 1e-5, up to 15 epochs |
| Regularisation | Flip, rotation, zoom, translation, contrast, brightness |
| Imbalance | Balanced class weights |
| Callbacks | EarlyStopping (val_accuracy, patience 5, restore best), ReduceLROnPlateau |

PRD §20 records an inconsistency between MobileNetV2 and MobileNetV3 in the
source chapters; MobileNetV2 was used, per the technical scope.

---

## 4.3 Classification results

Held-out test set, n = 579.

| Class | Precision | Recall | F1 | Support |
|---|---:|---:|---:|---:|
| MSV | 1.0000 | 0.9589 | 0.9790 | 146 |
| Common Rust | 1.0000 | 0.9833 | 0.9916 | 180 |
| Grey Leaf Spot | 0.8966 | 1.0000 | 0.9455 | 78 |
| Healthy | 1.0000 | 1.0000 | 1.0000 | 175 |
| **Macro avg** | **0.9741** | **0.9856** | **0.9790** | 579 |
| **Weighted avg** | 0.9861 | 0.9845 | 0.9847 | 579 |

**Overall accuracy: 0.9845.**

### Confusion matrix (`docs/model/confusion_matrix.png`)

Rows are true classes, columns predicted:

| | MSV | Rust | GLS | Healthy |
|---|---:|---:|---:|---:|
| **MSV** | 140 | 0 | 6 | 0 |
| **Common Rust** | 0 | 177 | 3 | 0 |
| **Grey Leaf Spot** | 0 | 0 | 78 | 0 |
| **Healthy** | 0 | 0 | 0 | 175 |

### Discussion

**All nine errors resolve to Grey Leaf Spot, and none resolve out of it.** GLS
attains perfect recall (1.0000) but the lowest precision (0.8966). This is a
direct consequence of balanced class weighting: GLS is the smallest class at 513
images, receives the largest weight, and the model consequently over-predicts
it. For a field diagnostic this is the preferable direction of error — a missed
infection costs more than a second look — but it should be stated as a
deliberate trade-off rather than left for a reader to infer.

**The Healthy class is perfectly separated in both directions.** No healthy leaf
was classified as diseased and no diseased leaf as healthy. This is the single
most consequential property for a farmer-facing tool.

**Evidence against a background-shortcut artefact.** MSV is the only
field-acquired class; the other three are laboratory imagery on uniform
backgrounds. Had the network learned to separate classes by background
statistics rather than lesion morphology, MSV would be trivially and perfectly
separable. Instead, six MSV images were confused with Grey Leaf Spot, indicating
the network attends to lesion appearance across the domain gap. This does not
eliminate the concern, but it is direct evidence against the most likely
failure mode of a two-source dataset.

---

## 4.4 Confidence threshold

PRD §9.2 quotes 95% as an example threshold and §20 requires the operational
value to be justified from validation results. The sweep below measures, for
each threshold, the proportion of scans retained (coverage) and the accuracy of
those retained (precision).

| Threshold | Kept | Coverage | Precision |
|---:|---:|---:|---:|
| 0.50 | 579 | 100.0% | 98.4% |
| 0.60 | 576 | 99.5% | 98.6% |
| **0.70** | **573** | **99.0%** | **99.0%** |
| 0.80 | 568 | 98.1% | 99.3% |
| 0.90 | 560 | 96.7% | 99.5% |
| 0.95 | 555 | 95.9% | 99.6% |
| 0.99 | 521 | 90.0% | 99.6% |

**Adopted: 0.70.** Moving from 0.70 to 0.95 buys 0.6 percentage points of
precision (99.0% -> 99.6%) while rejecting an additional 3.1% of scans. In
field use each rejection costs a farmer a repeated capture, so the marginal
precision does not justify the friction. Returns flatten above 0.95 — 0.99
discards 10% of scans for no measurable precision gain.

The threshold is user-adjustable in Settings and is **recorded on every stored
observation** (`Scan.thresholdUsed`), so historical records remain interpretable
if the operational value is later revised.

---

## 4.5 On-device performance

Measured on the Android emulator (`Medium_Phone_API_36.0`, API 36, arm64), debug
build. Each figure is wall-clock time for the complete `classify()` call: file
read, JPEG decode, centre-crop, resize to 224x224, normalisation, and
interpreter invocation.

| Run | Time |
|---|---:|
| 1 | 2,335 ms |
| 2 | 4,737 ms |
| 3 (offline) | 3,115 ms |
| 4 (system under load) | 26,075 ms |

| Artefact | Size |
|---|---:|
| TFLite float16 (deployed) | 4.47 MB |
| TFLite int8 | 2.72 MB |
| Keras source model | 24.4 MB |

**These figures are not representative of production hardware and must not be
quoted as such.** They are produced by a debug build on an emulator performing
binary translation, without a GPU or NNAPI delegate, and they include image
decode and preprocessing rather than inference alone. Run 4 was recorded while
the host was heavily loaded and is an outlier.

Before this section is finalised, latency must be re-measured on a physical
Android device in release mode. The int8 export is available as a further
optimisation if required, and a GPU or NNAPI delegate is the next lever after
that.

---

## 4.6 System testing

Full results in `docs/acceptance-tests.md`. Verified on-device:

| ID | Test | Result |
|---|---|---|
| AT-01 | Offline scan | **Pass.** Airplane mode, no default network. Full inference completed: MSV 89.3%, 3,115 ms. |
| AT-02 | Prediction | **Pass.** Class, confidence and full four-class ranking displayed. |
| AT-03 | Low confidence | **Pass.** A 69.1% result raised the low-confidence panel, demoted saving to "Save anyway as unconfirmed", and persisted with an unconfirmed flag. |
| AT-04 | GPS | **Pass.** 7.37750, 3.94700 (+/-5 m) attached. Absence of a fix stores the record without coordinates rather than discarding it. |
| AT-05 | Local save | **Pass.** Observation persisted offline to SQLite with its image; visible in history and on the map. |
| AT-06 | Sync | **Pass.** On reconnection, pending records uploaded automatically to `users/{uid}/scans/{scanId}` with no user action. |
| AT-07 | Map | **Pass.** Class-coloured pin rendered at recorded coordinates over live map tiles. |
| AT-08 | History | **Pass.** Per-user scoped, filterable by class. |
| AT-09 | Security | **Partial.** Rules published and enforced; owner writes succeed. Cross-user denial still to be demonstrated with a second account. |
| AT-10 | Performance | **Pass, provisional.** Measured, but on emulator only — see §4.5. |
| AT-11 | Scope conformance | **Pass.** Enforced at three layers: the `DiseaseClass` enum, a startup assertion on the model's output tensor width, and a server-side Firestore rule. |

### Reliability under backend failure

Two genuine backend failures occurred during testing and both were handled
without data loss, which constitutes direct evidence for the offline-first
requirement (FR-09):

1. Firestore not yet provisioned — write rejected with *"Cloud Firestore API has
   not been used in project"*.
2. Firestore provisioned but security rules not yet published — write rejected
   with *"Missing or insufficient permissions"*.

In both cases the observation was already committed to local storage before any
upload was attempted. The dashboard displayed the pending count with a retry
control, and all records synchronised successfully once the backend was
corrected. No observation was lost in either failure.

A defect was also found and fixed during this testing: automatic synchronisation
did not fire on reconnection, because the connectivity event arrives when the
network *interface* appears, which precedes the link becoming usable. The sweep
found no usable network, aborted, and never retried. Synchronisation now retries
with increasing delay and is driven through a single path that also refreshes
the interface.

---

## 4.7 Limitations

1. **Training data is predominantly laboratory imagery.** Three of four classes
   come from PlantVillage, where leaves are detached and photographed against
   uniform backgrounds. Field performance on cluttered backgrounds, variable
   lighting and partial occlusion is expected to be lower than 98.4%.
2. **No field-only stress test was performed.** The notebook provides one, but
   no held-out in-field image set was assembled, so the domain-shift claim in
   §4.3 rests on the confusion-matrix argument alone. This is the single most
   valuable addition to future work.
3. **Class imbalance persists.** Grey Leaf Spot has 513 images against Common
   Rust's 1,192, and this shows directly in its precision.
4. **MSV originates from Ghana, not Nigeria.** The closest available public
   proxy, but not the target population.
5. **Latency is unmeasured on real hardware** (§4.5).
6. **Diseases outside the four classes are undetected** and will be forced into
   one of the supported labels. The application states this explicitly in its
   disease catalogue.
7. **Only single-leaf close-up capture is supported.** Whole-plant and
   whole-field assessment are out of scope.
8. **GPS accuracy varies** with device and canopy cover; the recorded accuracy
   radius is stored per observation.
