import java.util.Properties

plugins {
    id("com.android.application")
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

val localProperties = Properties().apply {
    rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use(::load)
}

data class BuildEnvironment(
    val name: String,
    val apiBaseUrl: String,
    val audienceHost: String,
    val audienceId: String,
    val facebookAppId: String,
    val appleServicesId: String,
    val audienceKitEnvironment: String,
    val displayName: String,
)

val environments = mapOf(
    "debug" to BuildEnvironment(
        name = "debug",
        apiBaseUrl = "https://api.audiencekit.com",
        audienceHost = "hack-different.admin.audiencekit.com",
        audienceId = "2416ce6c-f28a-4460-8b6f-840f3c0027c9",
        facebookAppId = "713525445368431",
        appleServicesId = "com.hackdifferent.app",
        audienceKitEnvironment = "production",
        displayName = "Hack Different",
    ),
    "staging" to BuildEnvironment(
        name = "staging",
        apiBaseUrl = "https://api.next.audiencekit.com",
        audienceHost = "hack-different.admin.next.audiencekit.com",
        audienceId = "2416ce6c-f28a-4460-8b6f-840f3c0027c9",
        facebookAppId = "713525445368431",
        appleServicesId = "com.hackdifferent.app.next",
        audienceKitEnvironment = "staging",
        displayName = "Hack Different Next",
    ),
    "release" to BuildEnvironment(
        name = "release",
        apiBaseUrl = "https://api.audiencekit.com",
        audienceHost = "hack-different.admin.audiencekit.com",
        audienceId = "2416ce6c-f28a-4460-8b6f-840f3c0027c9",
        facebookAppId = "713525445368431",
        appleServicesId = "com.hackdifferent.app",
        audienceKitEnvironment = "production",
        displayName = "Hack Different",
    ),
)

android {
    namespace = "com.hackdifferent.app"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.hackdifferent.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
        }
        getByName("release") {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        create("staging") {
            initWith(getByName("release"))
            applicationIdSuffix = ".next"
            versionNameSuffix = "-next"
            signingConfig = signingConfigs.getByName("debug")
            matchingFallbacks += listOf("release")
        }
    }

    buildTypes.configureEach {
        val env = environments.getValue(name)
        buildConfigField("String", "API_BASE_URL", "\"${env.apiBaseUrl}\"")
        buildConfigField("String", "AUDIENCE_HOST", "\"${env.audienceHost}\"")
        buildConfigField("String", "AUDIENCE_ID", "\"${env.audienceId}\"")
        buildConfigField("String", "FACEBOOK_APP_ID", "\"${env.facebookAppId}\"")
        buildConfigField("String", "APPLE_SERVICES_ID", "\"${env.appleServicesId}\"")
        buildConfigField("String", "AUDIENCEKIT_ENVIRONMENT", "\"${env.audienceKitEnvironment}\"")
        resValue("string", "app_name", env.displayName)
    }

    buildFeatures {
        compose = true
        buildConfig = true
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    implementation(project(":core"))
    implementation(libs.audiencekit.android)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.browser)

    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)

    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)
    implementation(libs.okhttp)
    implementation(libs.zxing.core)

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.junit)
}
