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
    id("com.android.application") version "9.3.1" apply false
    id("com.android.library") version "9.3.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
}

// Automatically suppress legacy KGP warning for home_widget on AGP 9+
try {
    val pubCacheDirs = listOf(
        File(System.getProperty("user.home"), "AppData/Local/Pub/Cache/hosted/pub.dev"),
        File(System.getProperty("user.home"), ".pub-cache/hosted/pub.dev")
    )
    for (pubCacheDir in pubCacheDirs) {
        if (pubCacheDir.exists()) {
            pubCacheDir.listFiles { file -> file.isDirectory && file.name.startsWith("home_widget") }?.forEach { pluginDir ->
                val buildGradle = File(pluginDir, "android/build.gradle")
                if (buildGradle.exists()) {
                    val content = buildGradle.readText()
                    if (content.contains("apply plugin: 'kotlin-android'")) {
                        buildGradle.writeText(content.replace("apply plugin: 'kotlin-android'", "pluginManager.apply('kotlin-android')"))
                    }
                }
            }
        }
    }
} catch (_: Exception) {}

include(":app")
