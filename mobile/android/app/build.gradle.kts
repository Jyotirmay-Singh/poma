plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val uploadKey = System.getenv("POMA_ANDROID_KEYSTORE_FILE")
val uploadAlias = System.getenv("POMA_ANDROID_KEY_ALIAS")
val uploadStorePassword = System.getenv("POMA_ANDROID_STORE_PASSWORD")
val uploadKeyPassword = System.getenv("POMA_ANDROID_KEY_PASSWORD")
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val hasUploadSigning = listOf(uploadKey, uploadAlias, uploadStorePassword, uploadKeyPassword)
    .all { !it.isNullOrBlank() }
val unsignedInspection = System.getenv("POMA_ALLOW_UNSIGNED_RELEASE") == "1"
if (releaseRequested && !hasUploadSigning && !unsignedInspection) {
    throw GradleException("Release signing is missing. Supply the four POMA_ANDROID_* signing variables. " +
        "POMA_ALLOW_UNSIGNED_RELEASE=1 is for explicitly unsigned inspection artifacts only.")
}
// Aggregate tasks such as `build` can also select a release variant.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("release", ignoreCase = true) } &&
        !hasUploadSigning && !unsignedInspection) {
        throw GradleException("Release signing is missing; unsigned inspection requires POMA_ALLOW_UNSIGNED_RELEASE=1.")
    }
}

android {
    namespace = "dev.poma.poma"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.jyotirmaysingh.poma"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadSigning) {
            create("upload") {
                storeFile = file(uploadKey!!)
                keyAlias = uploadAlias
                storePassword = uploadStorePassword
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // There is deliberately no debug-signing fallback.
            signingConfig = if (hasUploadSigning) signingConfigs.getByName("upload") else null
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    testImplementation("junit:junit:4.13.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
