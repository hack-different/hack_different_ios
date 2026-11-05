//
//  HackDifferentTests.swift
//  HackDifferentTests
//

import AudienceKit
import Foundation
@testable import HackDifferent
import Testing

@Suite("Hack Different Domain & AudienceKit Configuration Tests")
struct HackDifferentTests {
    @Test("Default configuration targets Hack Different audience")
    func defaultConfiguration() {
        let config = AppConfiguration()
        #expect(config.host == "hack-different.admin.audiencekit.com")
        #expect(config.audienceID == "2416ce6c-f28a-4460-8b6f-840f3c0027c9")
        #expect(config.baseURL == URL(string: "https://api.audiencekit.com")!)

        let akConfig = config.audienceKitConfiguration
        #expect(akConfig.host == "hack-different.admin.audiencekit.com")
        #expect(akConfig.audienceID == "2416ce6c-f28a-4460-8b6f-840f3c0027c9")
    }

    @Test("SpaceCategory classifies hackerspaces vs conference venues")
    func spaceClassification() {
        let hackerspaceTag = Tag(id: "1", name: "Hackerspace")
        #expect(SpaceCategory.classify(tags: [hackerspaceTag], name: "Noisebridge") == .hackerspace)

        let conTag = Tag(id: "2", name: "Conference")
        #expect(SpaceCategory.classify(tags: [conTag], name: "Las Vegas Convention Center") == .conferenceVenue)
    }

    @Test("EventKind classifies conferences vs meetups")
    func eventKindClassification() {
        let meetup = ConferenceEvent(
            id: "evt-1",
            name: "Hardware Hacking Night",
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            endAt: Date(timeIntervalSince1970: 1_700_007_200),
            tags: [Tag(id: "t1", name: "Meetup")]
        )
        #expect(meetup.kind == .meetup)

        let conference = ConferenceEvent(
            id: "evt-2",
            name: "BSides Security Conference",
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            endAt: Date(timeIntervalSince1970: 1_700_172_800),
            tags: [Tag(id: "t2", name: "Conference")]
        )
        #expect(conference.kind == .conference)
    }

    @Test("DiscordChannelLink resolves from social links and descriptions")
    func discordResolution() {
        let link = SocialLink(
            id: "sl-1",
            handle: "hackdifferent",
            provider: "discord",
            url: URL(string: "https://discord.gg/hackdifferent")
        )
        let resolved = DiscordChannelLink.resolve(title: "Space Discord", socialLinks: [link])
        #expect(resolved?.webURL == URL(string: "https://discord.gg/hackdifferent"))

        let fromDescription = DiscordChannelLink.resolve(
            title: "Con Discord",
            description: "Join our hallway track at https://discord.gg/defcon2026 for live updates!"
        )
        #expect(fromDescription?.webURL == URL(string: "https://discord.gg/defcon2026"))
    }

    @Test("Money formatting displays currency or Free")
    func moneyFormatting() {
        let free = Money(cents: 0, currency: "usd")
        #expect(free.formattedAmount == "Free")

        let paid = Money(cents: 2500, currency: "usd")
        #expect(paid.formattedAmount.contains("25"))
    }
}
