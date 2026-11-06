package com.hackdifferent.core

import com.audiencekit.APIRequest
import com.audiencekit.Admission
import com.audiencekit.AudienceKitClient
import com.audiencekit.AudienceKitException
import com.audiencekit.CoverPurchase
import com.audiencekit.DeviceDescription
import com.audiencekit.EventWindow
import com.audiencekit.RSVPState
import com.audiencekit.SignInResult
import com.audiencekit.VenueCover
import com.audiencekit.event
import com.audiencekit.eventSeries
import com.audiencekit.events
import com.audiencekit.venueDetail
import com.audiencekit.venueOffers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Hack Different's domain operations on top of `AudienceKitClient`, matching iOS `HackDifferentAPI`: the SDK's
 * events and venue pages mapped to the app's view models, plus what the SDK doesn't offer (review sign-in).
 */
public class HackDifferentApi(
    public val client: AudienceKitClient,
    public val config: AppConfig,
) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        coerceInputValues = true
    }

    // region Venues (Hackerspaces & Conference Venues)

    public suspend fun venueDetail(id: String): SpaceDetail = coroutineScope {
        val cover = async { runCatching { client.venueCover(id) }.getOrNull() }
        val offers = async { runCatching { client.venueOffers(id) }.getOrDefault(emptyList()) }
        val detail = client.venueDetail(id, recentMessages = 5) ?: throw AudienceKitException.NotFound()
        var events = detail.upcomingEvents.orEmpty().map { it.toConferenceEvent() }
        if (events.isEmpty()) {
            events = runCatching { upcomingEvents(venueId = id) }.getOrDefault(events)
        }
        SpaceDetail(detail, upcomingEvents = events, ticketOffers = offers.await(), cover = cover.await())
    }

    // endregion

    // region Events (Conferences & Meetups)

    /** Upcoming events, then the recurring series that have no upcoming night listed under the same name. */
    public suspend fun upcomingEvents(localeId: String? = null, venueId: String? = null): List<ConferenceEvent> =
        coroutineScope {
            val series = async { runCatching { client.eventSeries(localeId = localeId, venueId = venueId) }.getOrNull() }
            val events = client.events(window = EventWindow.UPCOMING, localeId = localeId, venueId = venueId)

            val result = events.map { it.toConferenceEvent() }.toMutableList()
            val listedNames = result.mapTo(mutableSetOf()) { it.name.lowercase() }
            series.await().orEmpty().forEach {
                if (listedNames.add(it.name.lowercase())) result.add(it.toConferenceEvent())
            }
            result
        }

    public suspend fun eventDetail(id: String): ConferenceEvent =
        (client.event(id) ?: throw AudienceKitException.NotFound()).toConferenceEvent()

    public suspend fun setRsvp(state: RSVPState, eventId: String): RSVPState =
        client.setRSVP(state, eventId = eventId)

    // endregion

    // region Ticketing & Passes

    public suspend fun admissions(): List<Admission> = client.admissions()

    public suspend fun venueCover(venueId: String): VenueCover? = client.venueCover(venueId)

    public suspend fun buyCover(venueId: String): CoverPurchase = client.buyCover(venueId)

    public suspend fun confirmCover(admissionId: String): Admission = client.confirmCover(admissionId)

    public suspend fun refundAdmission(admissionId: String): Admission = client.refundAdmission(admissionId)

    // endregion

    // region App Review Sign-In Support

    public suspend fun isReviewSignInEnabled(): Boolean {
        @Serializable
        data class ReviewStatus(val enabled: Boolean? = null)

        val request = APIRequest(
            method = "GET",
            path = "/v1/token/review",
            queryItems = listOf("host" to config.host),
            authenticated = false,
        )
        return runCatching {
            val bytes = client.data(request)
            json.decodeFromString(ReviewStatus.serializer(), bytes.toString(Charsets.UTF_8)).enabled == true
        }.getOrDefault(false)
    }

    public suspend fun signInWithReviewCode(code: String, device: DeviceDescription): SignInResult =
        client.signInWithReviewCode(code, device)

    // endregion
}
