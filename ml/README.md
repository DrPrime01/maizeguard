# Model training

`maize_guard_training.ipynb` trains the four-class MobileNetV2 classifier and
exports it to TensorFlow Lite. Open it in Google Colab with a GPU runtime.

## The label contract

Four labels, in this exact order:

```
msv
common_rust
grey_leaf_spot
healthy
```

That order appears in three places and they must never drift apart:

1. `lib/domain/models/disease_class.dart` — the `DiseaseClass` enum
2. `assets/model/labels.txt`
3. `CLASS_NAMES` in the notebook

`test/disease_class_test.dart` asserts that (1) and (2) agree. Nothing can
check (3) automatically, so verify it by eye before training. A mismatch does
not crash anything — it silently relabels every prediction.

## The preprocessing contract

Inputs are scaled to **[-1, 1]** (`mobilenet_v2.preprocess_input`), applied **in
the data pipeline, not inside the model**. The exported TFLite therefore expects
an already-scaled tensor, which is what `Preprocess.toModelInput()` in
`lib/ml/preprocess.dart` produces:

```dart
buffer[i++] = (pixel.r / 127.5) - 1.0;
```

Move the rescaling into the model and the app will double-scale every image.
Accuracy collapses and nothing reports an error. Change both sides or neither.

## Datasets

PlantVillage covers three of the four classes. **It contains no Maize Streak
Virus** — its maize subset is Grey Leaf Spot, Common Rust, Northern Leaf Blight
and Healthy. MSV has to be sourced separately.

| Class | Source |
|---|---|
| `common_rust`, `grey_leaf_spot`, `healthy` | PlantVillage maize subset |
| `msv` | [CCMT crop pest & disease dataset (Ghana)](https://data.mendeley.com/datasets/bwh3zbpkpv/1), maize *streak virus* class — CC BY 4.0 |

Supplement or fallback for MSV:
[Tanzania maize dataset](https://data.mendeley.com/datasets/fkw49mz3xs/1) —
3,052 MSV images, CC BY 4.0.

### Watch the domain shift

PlantVillage images are lab-style: one detached leaf on a uniform background.
CCMT images are taken in the field. If MSV is the only class with field
backgrounds, the network can score very well by learning *"busy background =
MSV"* without ever looking at the leaf — and then fail completely on a real
farm. Section 7 of the notebook measures this with a field-only stress test.
Report both numbers.

## Installing a trained model

```bash
cp export/maize_mobilenetv2.tflite assets/model/maize_mobilenetv2.tflite
cp export/labels.txt               assets/model/labels.txt
```

Then in `lib/app/providers.dart`:

```dart
const bool kUseTrainedModel = true;   // was false
```

`TfliteClassifier.load()` validates the output shape at startup, so a model
with the wrong number of classes fails loudly instead of mislabelling scans.
