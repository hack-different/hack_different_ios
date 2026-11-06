# Hack Different for Android

Jetpack Compose Android client for the **Hack Different** community (`com.hackdifferent.app`), matching the iOS app in `../ios/` and built on the [AudienceKit Kotlin SDK](https://github.com/lwm-luminx/audience-kit-sdk.git).

## Modules

- `:core`: Plain Kotlin/JVM domain models (`ConferenceEvent`, `VenueDetail`, `ChatRoomTarget`, `DiscordChannelLink`), GraphQL documents (`HackDifferentApi`), and unit tests. Runs with only a JDK (`./gradlew :core:test`).
- `:app`: Android Jetpack Compose application (`com.hackdifferent.app`) with Sign in with Apple (`AppleWebSignIn`), Conferences & Meetups (`EventsScreen`), Hackerspaces & Venues (`SpacesScreen`), rotating HMAC-SHA256 QR passes (`PassesScreen`), and live Action Cable venue/regional chat (`ChatScreen`).

## Setup & Building

1. Clone [audience-kit-sdk](https://github.com/lwm-luminx/audience-kit-sdk.git) next to this repository (`../../audience-kit-sdk`) or at `../audience-kit-sdk`, or set `audiencekit.dir` in `android/local.properties` (or `AUDIENCEKIT_DIR`).
2. Run unit tests and assemble the debug APK:

```sh
cd android
./gradlew :core:test assembleDebug
```
