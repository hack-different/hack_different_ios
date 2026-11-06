pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
    }
}

rootProject.name = "hack_different_android"

val localProperties = java.util.Properties().apply {
    file("local.properties").takeIf { it.exists() }?.inputStream()?.use(::load)
}

val audienceKitSdk = listOfNotNull(
    providers.gradleProperty("audiencekit.dir").orNull,
    localProperties.getProperty("audiencekit.dir"),
    System.getenv("AUDIENCEKIT_DIR"),
    "../audience-kit-sdk",
    "../../audience-kit-sdk",
    "audience-kit-sdk",
    "../../staff-kit/audience-kit-sdk",
).map(::file)
    .firstOrNull { it.resolve("settings.gradle.kts").exists() }
    ?: error(
        "The AudienceKit Kotlin SDK wasn't found. Clone lwm-luminx/audience-kit-sdk next to this " +
            "repository, or set audiencekit.dir in android/local.properties.",
    )

localProperties.getProperty("sdk.dir")?.let { sdkDir ->
    val sdkLocalProperties = audienceKitSdk.resolve("local.properties")
    val existing = java.util.Properties().apply {
        sdkLocalProperties.takeIf { it.exists() }?.inputStream()?.use(::load)
    }
    if (existing.getProperty("sdk.dir") == null) {
        existing.setProperty("sdk.dir", sdkDir)
        sdkLocalProperties.outputStream().use { existing.store(it, "sdk.dir from hack_different_android") }
    }
}

includeBuild(audienceKitSdk)

// Plain Kotlin/JVM domain, GraphQL queries, Discord link resolution, and chat protocol.
include(":core")

// Android Jetpack Compose app (included whenever an Android SDK is available).
val hasAndroidSdk = listOf("ANDROID_HOME", "ANDROID_SDK_ROOT").any { System.getenv(it) != null } ||
    localProperties.getProperty("sdk.dir") != null
if (hasAndroidSdk) include(":app")
