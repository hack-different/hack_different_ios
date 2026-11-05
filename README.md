# Hack Different (iOS)

iOS app for the **Hack Different** community built on the [AudienceKit Swift SDK](https://github.com/lwm-luminx/audience-kit-sdk.git).

- **Audience Console**: `https://hack-different.admin.audiencekit.com/audiences/2416ce6c-f28a-4460-8b6f-840f3c0027c9`
- **Base URL**: `https://hackdiffe.rent`
- **Audience Host (`AUDIENCE_HOST`)**: `hack-different.admin.audiencekit.com`
- **Audience ID (`AUDIENCE_ID`)**: `2416ce6c-f28a-4460-8b6f-840f3c0027c9`

## Features

- **Sign in with Apple**: Native Apple ID authentication exchanged via `AudienceSession.signIn(appleIdentityToken:firstName:lastName:device:)` and persisted in `KeychainCredentialStore`. Also supports App Store Review code sign-in (`/v1/token/review`) when enabled on the audience.
- **Conferences & Meetups (`Events`)**: Browse upcoming conferences and local hacker meetups, filter by region (`Locale`) or event type, view speakers/organizers, and **RSVP** (`Going`, `Interested`, `Not Going`) via `AudienceSession.setRSVP(_:forEvent:)`.
- **Hackerspaces & Conference Venues (`Spaces`)**: Browse community hackerspaces and conference venues, view addresses/maps, upcoming schedules, and social links.
- **Ticketing & Live QR Passes (`Passes`)**: Support for external partner ticket offers (`tickets.offers`) and native AudienceKit admissions/passes (`buyCover`, `confirmCover`, `admissions`, `refundAdmission`) with offline-ready 30-second rotating HMAC-SHA256 QR codes (`CoverPass`).
- **Venue / Con Chat & Discord (`Chat`)**: Real-time chat rooms for every hackerspace, conference venue, and region over Action Cable (`AudienceCable`), paired with first-class Discord server & invite integration.

## Requirements

- Xcode 16+
- iOS 18.0+
- Swift 6.0 strict concurrency

## Building & Testing

```sh
xcodebuild build \
  -project HackDifferent.xcodeproj \
  -scheme HackDifferent \
  -destination 'generic/platform=iOS Simulator'
```
