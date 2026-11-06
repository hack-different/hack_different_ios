package com.hackdifferent.core

import com.audiencekit.Money
import com.audiencekit.SocialLink
import com.audiencekit.Tag
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class HackDifferentCoreTest {
    @Test
    fun `default configuration targets Hack Different audience on api audiencekit com`() {
        val config = AppConfig()
        assertEquals("hack-different.admin.audiencekit.com", config.host)
        assertEquals("2416ce6c-f28a-4460-8b6f-840f3c0027c9", config.audienceId)
        assertEquals("https://api.audiencekit.com", config.baseUrl)

        val akConfig = config.audienceKitConfiguration
        assertEquals("hack-different.admin.audiencekit.com", akConfig.host)
        assertEquals("2416ce6c-f28a-4460-8b6f-840f3c0027c9", akConfig.audienceId)
    }

    @Test
    fun `SpaceCategory classifies hackerspaces vs conference venues`() {
        val hackerspaceTag = Tag(id = "1", name = "Hackerspace")
        assertEquals(
            SpaceCategory.HACKERSPACE,
            SpaceCategory.classify(tags = listOf(hackerspaceTag), name = "Noisebridge"),
        )

        val conTag = Tag(id = "2", name = "Conference")
        assertEquals(
            SpaceCategory.CONFERENCE_VENUE,
            SpaceCategory.classify(tags = listOf(conTag), name = "Las Vegas Convention Center"),
        )
    }

    @Test
    fun `EventKind classifies conferences vs meetups`() {
        val meetup = ConferenceEvent(
            id = "evt-1",
            name = "Hardware Hacking Night",
            startAt = "2026-11-05T18:00:00Z",
            endAt = "2026-11-05T20:00:00Z",
            tags = listOf(Tag(id = "t1", name = "Meetup")),
        )
        assertEquals(EventKind.MEETUP, meetup.kind)

        val conference = ConferenceEvent(
            id = "evt-2",
            name = "BSides Security Conference",
            startAt = "2026-11-05T09:00:00Z",
            endAt = "2026-11-07T18:00:00Z",
            tags = listOf(Tag(id = "t2", name = "Conference")),
        )
        assertEquals(EventKind.CONFERENCE, conference.kind)
    }

    @Test
    fun `DiscordChannelLink resolves from social links and descriptions`() {
        val link = SocialLink(
            id = "sl-1",
            handle = "hackdifferent",
            provider = "discord",
            url = "https://discord.gg/hackdifferent",
        )
        val resolved = DiscordChannelLink.resolve(title = "Space Discord", socialLinks = listOf(link))
        assertEquals("https://discord.gg/hackdifferent", resolved?.webUrl)

        val fromDescription = DiscordChannelLink.resolve(
            title = "Con Discord",
            description = "Join our hallway track at https://discord.gg/defcon2026 for live updates!",
        )
        assertEquals("https://discord.gg/defcon2026", fromDescription?.webUrl)
    }

    @Test
    fun `Money formatting displays currency or Free`() {
        val free = Money(cents = 0, currency = "usd")
        assertEquals("Free", free.formattedAmount)

        val paid = Money(cents = 2500, currency = "usd")
        assertTrue(paid.formattedAmount.contains("25"))
    }
}
