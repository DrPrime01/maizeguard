pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // Flutter 3.35.3's template pins Kotlin 2.1.0, which is too old for this
    // dependency set and fails the build two ways:
    //   * firebase-auth 24.2.0 ships Kotlin metadata 2.3.0, which a 2.1.0
    //     compiler refuses outright ("Module was compiled with an incompatible
    //     version of Kotlin").
    //   * google_maps_flutter_android's generated Messages.kt crashes 2.1.0's
    //     FIR frontend ("source must not be null").
    // 2.3.0 is the floor that satisfies firebase-auth's metadata.
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false
    // Declared but not applied here — the app module applies it only when a
    // google-services.json is actually present (see app/build.gradle.kts).
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
