import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val keystoreFile = if (keystoreProperties.getProperty("storeFile") != null) {
    file(keystoreProperties.getProperty("storeFile"))
} else {
    file("upload-keystore.jks")
}

android {
    namespace = "com.zeparty.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (keystoreFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias") ?: "upload"
                keyPassword = keystoreProperties.getProperty("keyPassword") ?: "zeparty123"
                storeFile = keystoreFile
                storePassword = keystoreProperties.getProperty("storePassword") ?: "zeparty123"
            }
        }
    }

    defaultConfig {
        applicationId = "com.zeparty.app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Shrinking is left as the project had it (off). Turning R8 on needs a device test
            // pass for Agora / Socket.IO / Firebase reflection paths before shipping.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (keystoreFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }

    // Native libraries (Agora, Flutter engine) are the second largest part of the download.
    // Ship them per ABI: `flutter build appbundle` lets Play deliver one ABI per device, and
    // `flutter build apk --split-per-abi` produces one APK per ABI for sideloading.
    // (Do not configure `splits {}` here: the Flutter Gradle plugin manages it for those commands.)
    bundle {
        abi { enableSplit = true }
        density { enableSplit = true }
        language { enableSplit = true }
    }
}

// A release artifact must be signed with the upload keystore. The old silent fallback to the
// debug key produced builds the stores reject. This only fails the release assemble/bundle
// tasks themselves (debug builds and `flutter run` are unaffected); opt in to a debug-signed
// release for local testing with:  flutter build apk --release -PallowDebugSigning=true
if (!keystoreFile.exists() && project.findProperty("allowDebugSigning") != "true") {
    tasks.configureEach {
        if (name.matches(Regex("(assemble|bundle|package)\\w*Release\\w*"))) {
            doFirst {
                throw GradleException(
                    "Release signing keystore not found (android/key.properties -> storeFile, or android/app/upload-keystore.jks). " +
                    "Add it, or pass -PallowDebugSigning=true for a local debug-signed test build."
                )
            }
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
