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

    // maplibre_android 0.3.6 applies `org.jlleitschuh.gradle.ktlint` in its own
    // build.gradle.kts without a version and without a buildscript classpath
    // (0.3.5 still carried one), so the plugin is unresolvable and every
    // consumer build dies at that file. Supplying a default version here is the
    // only place a consumer can fix it. Drop this once upstream republishes.
    plugins {
        id("org.jlleitschuh.gradle.ktlint") version "14.2.0"
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.4.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.21" apply false
    // Reads android/app/google-services.json at build time: that is where the
    // FCM sender id comes from, so a build without it registers no token.
    id("com.google.gms.google-services") version "4.5.0" apply false
}

include(":app")
