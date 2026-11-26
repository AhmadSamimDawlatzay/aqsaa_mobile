import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.aqsaa.aqsaa_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Each installable app sets its final application ID in a product flavor.
        applicationId = "app.aqsaa"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "installation"
    productFlavors {
        create("demo") {
            dimension = "installation"
            applicationId = "app.aqsaa.demo"
            resValue("string", "app_name", "Aqsaa Demo")
        }
    }

    val demoFirebaseFile = file("src/demo/google-services.json")
    if (!demoFirebaseFile.exists()) {
        throw GradleException(
            "Demo Firebase configuration is missing: android/app/src/demo/google-services.json",
        )
    }
    val demoFirebaseText = demoFirebaseFile.readText()
    if (!demoFirebaseText.contains("\"project_id\": \"aqsaademo\"") ||
        !demoFirebaseText.contains("\"package_name\": \"app.aqsaa.demo\"")) {
        throw GradleException(
            "Demo Firebase configuration must match aqsaademo and app.aqsaa.demo.",
        )
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
    }
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            val releaseRequested =
                gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
            if (!keystorePropertiesFile.exists() && releaseRequested) {
                throw GradleException(
                    "Release signing is not configured. Create an uncommitted android/key.properties " +
                        "that points to the installation release keystore.",
                )
            }
            if (keystorePropertiesFile.exists()) {
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
