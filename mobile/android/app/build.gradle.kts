import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.axis.axis"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            val envFile = rootProject.file("../.env")
            val keyPropsFile = rootProject.file("key.properties")
            val props = Properties()

            if (envFile.exists()) {
                envFile.forEachLine { line ->
                    val trimmed = line.trim()
                    if (trimmed.isNotEmpty() && !trimmed.startsWith("#") && trimmed.contains("=")) {
                        val key = trimmed.substringBefore("=").trim()
                        val value = trimmed.substringAfter("=").trim().removeSurrounding("\"").removeSurrounding("'")
                        props[key] = value
                    }
                }
            }

            if (keyPropsFile.exists()) {
                FileInputStream(keyPropsFile).use { props.load(it) }
            }

            val storeFilePath = props.getProperty("KEYSTORE_PATH")
                ?: props.getProperty("storeFile")
                ?: System.getenv("KEYSTORE_PATH")
                ?: System.getenv("ANDROID_STORE_FILE")
                ?: "axis-release.jks"

            val resolvedStoreFile = if (file(storeFilePath).isAbsolute) {
                file(storeFilePath)
            } else {
                val inApp = file(storeFilePath)
                if (inApp.exists()) inApp else rootProject.file("app/$storeFilePath")
            }

            val resolvedKeyAlias = props.getProperty("KEY_ALIAS")
                ?: props.getProperty("keyAlias")
                ?: System.getenv("KEY_ALIAS")
                ?: System.getenv("ANDROID_KEY_ALIAS")

            val resolvedStorePassword = props.getProperty("KEYSTORE_PASSWORD")
                ?: props.getProperty("storePassword")
                ?: System.getenv("KEYSTORE_PASSWORD")
                ?: System.getenv("ANDROID_STORE_PASSWORD")

            val resolvedKeyPassword = props.getProperty("KEY_PASSWORD")
                ?: props.getProperty("keyPassword")
                ?: System.getenv("KEY_PASSWORD")
                ?: System.getenv("ANDROID_KEY_PASSWORD")

            if (resolvedStoreFile.exists() && !resolvedKeyAlias.isNullOrEmpty() && !resolvedStorePassword.isNullOrEmpty()) {
                storeFile = resolvedStoreFile
                keyAlias = resolvedKeyAlias
                storePassword = resolvedStorePassword
                keyPassword = resolvedKeyPassword ?: resolvedStorePassword
            } else {
                // Fallback to debug config if release keystore or credentials are not configured
                initWith(signingConfigs.getByName("debug"))
            }
        }
    }

    defaultConfig {
        applicationId = "com.axis.tasking"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "Axis"
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appLabel"] = "Axis (Dev)"
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            manifestPlaceholders["appLabel"] = "Axis"
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
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
