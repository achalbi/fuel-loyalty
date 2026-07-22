import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.google.services)
}

// Release signing + prod host come from a gitignored keystore.properties
// (see keystore.properties.example). Absent it, release builds stay unsigned.
val keystorePropsFile = rootProject.file("keystore.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) keystorePropsFile.inputStream().use { load(it) }
}
val prodApiBaseUrl = (keystoreProps.getProperty("apiBaseUrl")
    ?: System.getenv("PROD_API_BASE_URL")
    ?: "https://REPLACE_WITH_PROD_HOST/")

android {
    namespace = "com.acefuel.loyalty"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.acefuel.loyalty"
        minSdk = 26
        targetSdk = 36
        versionCode = 5
        versionName = "1.1.1"
    }

    signingConfigs {
        create("release") {
            if (keystorePropsFile.exists()) {
                // Resolve relative to the root project (android/), where
                // keystore.properties itself lives — not the app/ module.
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // Points at the deployed Cloud Run backend (fuel-loyalty-git in us-central1,
            // custom domain fly.thoughtbasics.com) so debug builds hit the real instance.
            // For local dev against the Rails server, swap this to "http://localhost:3007/"
            // and run `adb reverse tcp:3007 tcp:3007` (emulator would use 10.0.2.2).
            buildConfigField("String", "API_BASE_URL", "\"https://fly.thoughtbasics.com/\"")
        }
        release {
            // R8 minify is a follow-up: enable + add keep rules for
            // kotlinx.serialization DTOs, then verify a signed release on device.
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            buildConfigField("String", "API_BASE_URL", "\"$prodApiBaseUrl\"")
            if (keystorePropsFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.core.splashscreen)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons.extended)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.retrofit)
    implementation(libs.okhttp)
    implementation(libs.okhttp.logging)
    // Plate scanner (CameraX capture + ML Kit on-device fallback)
    implementation(libs.androidx.camera.core)
    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)
    implementation(libs.androidx.camera.view)
    implementation(libs.mlkit.text.recognition)
    implementation(libs.accompanist.permissions)
    // KYC image thumbnails (operator profile + ID-card previews)
    implementation(libs.coil.compose)
    // FCM push
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)
    debugImplementation(libs.androidx.ui.tooling)
}
