plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningValues = mapOf(
    "storeFile" to System.getenv("ORDIN_ANDROID_KEYSTORE_PATH"),
    "storePassword" to System.getenv("ORDIN_ANDROID_KEYSTORE_PASSWORD"),
    "keyAlias" to System.getenv("ORDIN_ANDROID_KEY_ALIAS"),
    "keyPassword" to System.getenv("ORDIN_ANDROID_KEY_PASSWORD"),
)
val configuredReleaseSigningValues = releaseSigningValues.values.count { !it.isNullOrBlank() }
val hasReleaseSigning = configuredReleaseSigningValues == releaseSigningValues.size
val allowUnsignedReleaseCheck =
    System.getenv("ORDIN_ALLOW_UNSIGNED_RELEASE_CHECK") == "1"
val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.substringAfterLast(':').contains("release", ignoreCase = true)
}

if (configuredReleaseSigningValues in 1 until releaseSigningValues.size) {
    throw GradleException(
        "Android release signing is only partially configured. Set all ORDIN_ANDROID_KEYSTORE_* variables.",
    )
}

if (releaseTaskRequested && !hasReleaseSigning && !allowUnsignedReleaseCheck) {
    throw GradleException(
        "Android release signing is not configured. Set all ORDIN_ANDROID_KEYSTORE_* variables. " +
            "ORDIN_ALLOW_UNSIGNED_RELEASE_CHECK=1 is reserved for non-distributable CI build checks.",
    )
}

android {
    namespace = "com.ordin.foods"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ordin.foods"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseSigningValues.getValue("storeFile")!!)
                storePassword = releaseSigningValues.getValue("storePassword")
                keyAlias = releaseSigningValues.getValue("keyAlias")
                keyPassword = releaseSigningValues.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
