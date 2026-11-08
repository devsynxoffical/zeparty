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

android {
    namespace = "com.zeparty.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    val keystoreFile = if (keystoreProperties.getProperty("storeFile") != null) {
        file(keystoreProperties.getProperty("storeFile"))
    } else {
        file("upload-keystore.jks")
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
            // R8 code shrinking + resource shrinking. Keep rules for Flutter, Agora, Socket.IO,
            // Gson and Google Sign-In live in proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // A release build must be signed with the upload keystore. Falling back to the debug
            // key silently produced store-rejected builds; opt in explicitly for local testing with
            //   flutter build apk --release -PallowDebugSigning=true
            if (keystoreFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else if (project.findProperty("allowDebugSigning") == "true") {
                signingConfig = signingConfigs.getByName("debug")
            } else {
                throw GradleException(
                    "Release signing keystore not found (android/key.properties -> storeFile, or android/app/upload-keystore.jks). " +
                    "Add it, or pass -PallowDebugSigning=true for a local debug-signed test build."
                )
            }
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
