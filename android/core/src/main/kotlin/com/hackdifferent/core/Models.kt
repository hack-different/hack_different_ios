package com.hackdifferent.core

import com.audiencekit.Admission
import com.audiencekit.AdmissionOffer
import com.audiencekit.AudienceLocale
import com.audiencekit.ChatMessage
import com.audiencekit.Coordinate
import com.audiencekit.CoverCharge
import com.audiencekit.Event
import com.audiencekit.EventPerson
import com.audiencekit.EventSeries
import com.audiencekit.EventVenue
import com.audiencekit.Money
import com.audiencekit.RSVPState
import com.audiencekit.Tag
import com.audiencekit.SocialLink
import com.audiencekit.Venue
import com.audiencekit.VenueCover
import com.audiencekit.VenueDetail
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

public data class EventVenueSummary(
    val id: String,
    val name: String,
    val photoUrl: String? = null,
    val address: String? = null,
    /** Parsed by the SDK from the API's WKT point (`POINT (lng lat)`). */
    val coordinate: Coordinate? = null,
) {
    public constructor(venue: EventVenue, displayName: String?) : this(
        id = venue.id,
        name = venue.name ?: displayName ?: "Venue",
        photoUrl = venue.photoUrl,
        address = venue.location?.address,
        coordinate = venue.location?.coordinate,
    )
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
    val recurrenceText: String? = null,
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
    val hosts: List<EventPerson> = emptyList(),
    val lineup: List<EventPerson> = emptyList(),
    val ticketUrl: String? = null,
    val ticketOffers: List<AdmissionOffer> = emptyList(),
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

/** Maps an SDK [Event] into the view model. */
public fun Event.toConferenceEvent(): ConferenceEvent {
    val summary = venue?.let { EventVenueSummary(it, venueName) }
    return ConferenceEvent(
        id = id,
        name = name ?: "Untitled Event",
        description = description,
        startAt = startAt,
        endAt = endAt,
        isFeatured = isFeatured,
        isCanceled = isCanceled,
        bannerUrl = bannerUrl,
        sourceUrl = sourceUrl,
        venueDisplayName = venueName ?: summary?.name ?: locale?.name ?: locale?.label ?: "Hack Different",
        venue = summary,
        locale = locale,
        tags = tags,
        rsvpState = rsvp?.mine ?: RSVPState.UNSURE,
        rsvpCount = rsvp?.count ?: 0,
        hosts = hosts.orEmpty(),
        lineup = lineup.orEmpty(),
        ticketUrl = ticketUrl,
        ticketOffers = ticketOffers.orEmpty(),
        coverCharge = coverCharge,
    )
}

/** Maps an SDK [EventSeries] (a recurring meetup) into the view model. */
public fun EventSeries.toConferenceEvent(): ConferenceEvent {
    val summary = venue?.let { EventVenueSummary(it, venueName) }
    val schedule = when {
        !recurrenceText.isNullOrBlank() && startTime.isNotBlank() -> "$recurrenceText • $startTime"
        !recurrenceText.isNullOrBlank() -> recurrenceText
        else -> startTime
    }
    return ConferenceEvent(
        id = id,
        name = name,
        description = description,
        startAt = startsOn,
        recurrenceText = schedule,
        bannerUrl = bannerUrl,
        venueDisplayName = venueName ?: summary?.name ?: locale?.name ?: locale?.label ?: "Hack Different",
        venue = summary,
        locale = locale,
        tags = tags,
    )
}

/**
 * Rich detail for a Hackerspace or Conference Venue: the SDK's [VenueDetail] with its events mapped to
 * [ConferenceEvent]s, plus the venue's ticketing (offers, tonight's cover and the viewer's pass).
 */
public data class SpaceDetail(
    val venue: Venue,
    val description: String? = null,
    val address: String? = venue.location?.address,
    val phone: String? = null,
    val socialLinks: List<SocialLink> = emptyList(),
    val chatOpen: Boolean = false,
    val recentMessages: List<ChatMessage> = emptyList(),
    val upcomingEvents: List<ConferenceEvent> = emptyList(),
    val ticketOffers: List<AdmissionOffer> = emptyList(),
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

public fun SpaceDetail(
    detail: VenueDetail,
    upcomingEvents: List<ConferenceEvent>,
    ticketOffers: List<AdmissionOffer>,
    cover: VenueCover?,
): SpaceDetail = SpaceDetail(
    venue = detail.venue,
    description = detail.description,
    address = detail.address ?: detail.venue.location?.address,
    phone = detail.phone,
    socialLinks = detail.socialLinks.orEmpty(),
    chatOpen = detail.chatOpen ?: false,
    recentMessages = detail.recentMessages.orEmpty(),
    upcomingEvents = upcomingEvents,
    ticketOffers = ticketOffers,
    coverCharge = cover?.coverCharge,
    viewerAdmission = cover?.viewerAdmission,
)

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
