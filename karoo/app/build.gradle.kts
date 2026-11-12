import java.io.FileInputStream
import java.time.Duration
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.roborazzi)
}

// Load keystore.properties for release signing
val keystorePropertiesFile: File = rootProject.file("keystore.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "fr.pedalons.karoo"
    compileSdk = 37

    defaultConfig {
        applicationId = "fr.pedalons.karoo"
        minSdk = 26
        // Karoo is Android 12 -> targetSdk must be 32
        //noinspection ExpiredTargetSdkVersion
        targetSdk = 32
        versionCode = System.getenv("KAROO_VERSION_CODE")?.toIntOrNull() ?: 1
        versionName = System.getenv("KAROO_VERSION_NAME") ?: "1.0.0"
        buildConfigField("String", "PEDALONS_BASE_URL", "\"https://www.pedalons.fr\"")
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    null
                }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    testOptions {
        unitTests {
            // Robolectric needs the merged resources and the manifest (strings, drawables, theme).
            isIncludeAndroidResources = true
            all {
                // A regression makes many waitUntil(10 s) calls time out one after the other (a
                // mutated build took ~10 min): fail the task rather than hang CI.
                it.timeout.set(Duration.ofMinutes(15))
            }
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    // Karoo SDK
    implementation(libs.karoo.ext)

    // Ktor HTTP client with Karoo engine
    implementation(libs.ktor.client.core)
    implementation(libs.ktor.client.content.negotiation)
    implementation(libs.ktor.serialization.json)
    implementation(libs.ktor.client.karoo)

    // Kotlin Serialization
    implementation(libs.kotlinx.serialization.json)

    // Compose BOM
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    debugImplementation(libs.compose.ui.tooling)

    // AndroidX
    implementation(libs.core.ktx)
    implementation(libs.lifecycle.runtime)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.activity.compose)

    // DataStore for token storage (plain app-private storage, not encrypted)
    implementation(libs.datastore)

    // QR Code generation
    implementation(libs.zxing)
}

dependencies {
    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.ext.junit)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.ktor.client.mock)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
    debugImplementation(libs.compose.ui.test.manifest)
}
