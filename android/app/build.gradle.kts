plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flavour <-> Dart entry-point guard (flutter-flavors skill). Android has no
// per-flavour Dart target: the Flutter tool passes `-Ptarget=<file>`, so a
// release of one flavour built from the other flavour's main file would
// otherwise succeed silently. Checked at configuration time, before compiling.
val flavorEntryPoints = mapOf("production" to "main_prod.dart", "development" to "main_dev.dart")
val flutterTarget = (project.findProperty("target") as String?) ?: "lib/main.dart"
val releaseTasks = gradle.startParameter.taskNames.filter {
    it.contains("Release") && (it.contains("assemble") || it.contains("bundle"))
}
flavorEntryPoints.forEach { (flavor, entry) ->
    val releasingFlavor = releaseTasks.any { it.contains(flavor, ignoreCase = true) }
    if (releasingFlavor && !flutterTarget.endsWith(entry)) {
        throw GradleException(
            "The $flavor release must be built from $entry (got $flutterTarget). " +
                "Run: flutter build apk --flavor $flavor -t lib/$entry"
        )
    }
}
// Only production is ever distributed (owner decision, 2026-10-04): a development
// release APK/bundle is refused outright. Use --debug or --profile for dev builds.
if (releaseTasks.any { it.contains("development", ignoreCase = true) }) {
    throw GradleException(
        "Development builds are never distributed: build the dev flavour with --debug or --profile, " +
            "or ship: flutter build apk --flavor production -t lib/main_prod.dart --split-per-abi"
    )
}

android {
    // Code package. The install ID is applicationId (+ the flavour suffix).
    namespace = "com.tubedownloader.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time on Android < 8.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.tubedownloader.app"
        // FFmpeg (ffmpeg_kit_flutter_new_audio) needs API 24+.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. With --split-per-abi Flutter adds
        // 1000 * ABI_VERSION automatically.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // AGP 9 turns resValue() off by default; the per-flavour app_name needs it.
    buildFeatures {
        resValues = true
    }

    flavorDimensions += "default"
    productFlavors {
        create("production") {
            dimension = "default"
            // Launcher labels are kept short (phones truncate ~12 characters);
            // the full "Tube Downloader" is used on desktop and in About.
            resValue("string", "app_name", "Tube DL")
        }
        create("development") {
            dimension = "default"
            applicationIdSuffix = ".dev" // installs beside production
            resValue("string", "app_name", "Tube DL Dev") // same as the iOS dev name
        }
    }

    buildTypes {
        release {
            // Debug-key signing until Phase 7 (release keystore created by the owner,
            // stored outside the repo, wired through android/key.properties).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
