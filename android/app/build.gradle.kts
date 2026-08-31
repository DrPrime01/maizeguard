import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// The Google Maps SDK key is read from local.properties, which is gitignored.
// Keeping it out of the manifest and out of version control means the repo can
// be shared or submitted without leaking a billable credential.
val localProperties = Properties()
rootProject.file("local.properties").takeIf { it.exists() }?.let { file ->
    FileInputStream(file).use { localProperties.load(it) }
}
val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY") ?: ""

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase is opt-in at build time.
//
// The google-services plugin hard-fails the build when google-services.json is
// missing, which would make Firebase mandatory — the opposite of this app's
// offline-first design. Applying it conditionally means the project builds and
// runs in local mode with no Firebase at all, and lights up the moment the
// config file is dropped into android/app/.
val googleServicesConfig = file("google-services.json")
if (googleServicesConfig.exists()) {
    apply(plugin = "com.google.gms.google-services")
    logger.lifecycle("Firebase: google-services.json found, Firebase enabled.")
} else {
    logger.lifecycle("Firebase: no google-services.json, building in local mode.")
}

android {
    namespace = "ng.edu.miva.maize_guard"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    androidResources {
        // Keep .tflite uncompressed in the APK. Interpreter.fromAsset reads
        // through rootBundle so it would survive compression, but leaving the
        // model uncompressed avoids an inflate on every cold start and keeps
        // the option of switching to a memory-mapped load later.
        noCompress += "tflite"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }


    defaultConfig {
        applicationId = "ng.edu.miva.maize_guard"
        // Firebase Auth and Cloud Firestore require API 23+; 24 gives headroom
        // and still covers the low-end Android hardware this app targets.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Kotlin 2.3.0 removed the `kotlinOptions` DSL that Flutter's template used.
// This is its replacement; the JVM target must stay in step with the
// compileOptions above or Gradle fails with a target mismatch.
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}
