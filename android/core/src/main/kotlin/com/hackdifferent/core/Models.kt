package com.hackdifferent.core

import com.audiencekit.Admission
import com.audiencekit.AudienceLocale
import com.audiencekit.CoverCharge
import com.audiencekit.Money
import com.audiencekit.RSVPState
import com.audiencekit.Tag
import com.audiencekit.Venue
import kotlinx.serialization.Serializable
import java.text.NumberFormat
import java.time.Instant
import java.util.Currency
import java.util.Locale

/**
 * Categorizes an event in Hack Different as a Conference or a Meetup.
 */
public enum class EventKind(public val label: String, public val badgeLabel: String) {
    ALL("All Events", "Event"),
    CONFERENCE("Conferences", "Conference"),
    MEETUP("Meetups", "Meetup"),
}

/**
 * Categorizes a venue in Hack Different as a Hackerspace or Conference Venue.
 */
public enum class SpaceCategory(public val label: String) {
    ALL("All Spaces"),
    HACKERSPACE("Hackerspaces"),
    CONFERENCE_VENUE("Con Venues"),
    ;

    public companion object {
        public fun classify(tags: List<Tag> = emptyList(), name: String): SpaceCategory {
            val tagNames = tags.map { it.name.lowercase() }
            val loweredName = name.lowercase()
            val isConferenceVenue = tagNames.any {
                it.contains("con") || it.contains("conference") || it.contains("hotel") || it.contains("center")
            } || loweredName.contains("con") || loweredName.contains("center") || loweredName.contains("convention")
            return if (isConferenceVenue) CONFERENCE_VENUE else HACKERSPACE
        }
    }
}

@Serializable
public data class EventOrganizer(
    val id: String,
    val name: String,
    val avatarUrl: String? = null,
)

@Serializable
public data class EventVenueSummary(
    val id: String,
    val name: String,
    val photoUrl: String? = null,
    val address: String? = null,
)

@Serializable
public data class TicketOffer(
    val price: Money? = null,
    val seller: Seller,
    val url: String? = null,
) {
    @Serializable
    public data class Seller(
        val key: String,
        val name: String,
    )

    public val id: String
        get() = "${seller.key}-${url ?: "in-app"}-${price?.cents ?: 0}"
}

/**
 * A conference or meetup event in the Hack Different audience.
 */
public data class ConferenceEvent(
    val id: String,
    val name: String,
    val description: String? = null,
    val startAt: String? = null,
    val endAt: String? = null,
    val isFeatured: Boolean = false,
    val isCanceled: Boolean = false,
    val bannerUrl: String? = null,
    val sourceUrl: String? = null,
    val venueDisplayName: String = "To be announced",
    val venue: EventVenueSummary? = null,
    val locale: AudienceLocale? = null,
    val tags: List<Tag> = emptyList(),
    val rsvpState: RSVPState = RSVPState.UNSURE,
    val rsvpCount: Int = 0,
    val hosts: List<EventOrganizer> = emptyList(),
    val lineup: List<EventOrganizer> = emptyList(),
    val ticketUrl: String? = null,
    val ticketOffers: List<TicketOffer> = emptyList(),
    val coverCharge: CoverCharge? = null,
) {
    public val kind: EventKind
        get() {
            val tagNames = tags.map { it.name.lowercase() }
            val loweredName = name.lowercase()
            if (tagNames.any { it.contains("con") || it.contains("conference") || it.contains("summit") || it.contains("ctf") } ||
                loweredName.contains("con") || loweredName.contains("conference") ||
                loweredName.contains("summit") || loweredName.contains("bsides") || loweredName.contains("defcon")
            ) {
                return EventKind.CONFERENCE
            }
            val startEpoch = startAt?.let { runCatching { Instant.parse(it).epochSecond }.getOrNull() }
            val endEpoch = endAt?.let { runCatching { Instant.parse(it).epochSecond }.getOrNull() }
            if (startEpoch != null && endEpoch != null && (endEpoch - startEpoch) >= 8 * 3600) {
                return EventKind.CONFERENCE
            }
            return EventKind.MEETUP
        }

    public val hasTicketing: Boolean
        get() = !ticketUrl.isNullOrBlank() || ticketOffers.isNotEmpty() || coverCharge != null

    public val primaryTicketUrl: String?
        get() = ticketUrl?.takeIf { it.isNotBlank() } ?: ticketOffers.mapNotNull { it.url?.takeIf(String::isNotBlank) }.firstOrNull()

    public val lowestTicketPrice: Money?
        get() = coverCharge?.total ?: ticketOffers.mapNotNull { it.price }.minByOrNull { it.cents }

    public val discordLink: DiscordChannelLink?
        get() = DiscordChannelLink.resolve(
            title = "$name Discord",
            description = description,
            sourceUrl = sourceUrl,
        )
}

/**
 * Rich detail for a Hackerspace or Conference Venue.
 */
public data class VenueDetail(
    val venue: Venue,
    val description: String? = null,
    val address: String? = venue.location?.address,
    val phone: String? = null,
    val socialLinks: List<SocialLink> = emptyList(),
    val chatOpen: Boolean = false,
    val recentMessages: List<ChatMessageItem> = emptyList(),
    val upcomingEvents: List<ConferenceEvent> = emptyList(),
    val ticketOffers: List<TicketOffer> = emptyList(),
    val coverCharge: CoverCharge? = null,
    val viewerAdmission: Admission? = null,
) {
    public val id: String get() = venue.id
    public val name: String get() = venue.name

    public val category: SpaceCategory
        get() = SpaceCategory.classify(tags = venue.tags, name = venue.name)

    public val discordLink: DiscordChannelLink?
        get() = DiscordChannelLink.resolve(
            title = "${venue.name} Discord",
            socialLinks = socialLinks,
            description = description,
        )
}

/** Formatted currency string (e.g. "$25.00" or "Free" when 0). */
public val Money.formattedAmount: String
    get() {
        if (cents == 0) return "Free"
        return runCatching {
            val format = NumberFormat.getCurrencyInstance(Locale.US)
            format.currency = Currency.getInstance(currency.uppercase())
            format.format(cents / 100.0)
        }.getOrElse { "$%.2f".format(cents / 100.0) }
    }
