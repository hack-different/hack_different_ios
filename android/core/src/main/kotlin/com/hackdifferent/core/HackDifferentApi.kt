package com.hackdifferent.core

import com.audiencekit.APIRequest
import com.audiencekit.Admission
import com.audiencekit.AudienceKitClient
import com.audiencekit.AudienceKitException
import com.audiencekit.AudienceLocale
import com.audiencekit.CoverCharge
import com.audiencekit.CoverPurchase
import com.audiencekit.DeviceDescription
import com.audiencekit.RSVPState
import com.audiencekit.SignInResult
import com.audiencekit.Tag
import com.audiencekit.Venue
import com.audiencekit.VenueCover
import com.audiencekit.graphQLVariables
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/**
 * Typed domain operations built on top of `AudienceKitClient`, matching iOS `HackDifferentAPI`.
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

    public suspend fun venues(): List<Venue> = client.venues()

    public suspend fun locales(): List<AudienceLocale> = client.locales()

    public suspend fun venueDetail(id: String): VenueDetail {
        val response = client.graphQL(
            query = Documents.VENUE_DETAIL,
            deserializer = VenueDetailGraphQLResponse.serializer(),
            variables = graphQLVariables("id" to id),
            operationName = "VenueDetail",
            json = json,
        )
        val wire = response.venues?.venue ?: throw AudienceKitException.NotFound()
        return wire.toVenueDetail()
    }

    // endregion

    // region Events (Conferences & Meetups)

    public suspend fun upcomingEvents(localeId: String? = null, venueId: String? = null): List<ConferenceEvent> {
        val pairs = buildList {
            if (localeId != null) add("localeId" to localeId)
            if (venueId != null) add("venueId" to venueId)
        }
        val response = client.graphQL(
            query = Documents.UPCOMING_EVENTS,
            deserializer = UpcomingEventsGraphQLResponse.serializer(),
            variables = if (pairs.isEmpty()) null else graphQLVariables(*pairs.toTypedArray()),
            operationName = "UpcomingEvents",
            json = json,
        )
        return response.events?.list?.items.orEmpty().map { it.toConferenceEvent() }
    }

    public suspend fun eventDetail(id: String): ConferenceEvent {
        val response = client.graphQL(
            query = Documents.EVENT_DETAIL,
            deserializer = EventDetailGraphQLResponse.serializer(),
            variables = graphQLVariables("id" to id),
            operationName = "EventDetail",
            json = json,
        )
        val wire = response.events?.event ?: throw AudienceKitException.NotFound()
        return wire.toConferenceEvent()
    }

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

    // region Chat

    public suspend fun sendChatMessage(text: String, room: ChatRoomTarget): ChatMessageItem {
        val input = mapOf(
            room.argumentName to room.recordId.lowercase(),
            "message" to text,
        )
        val response = client.graphQL(
            query = Documents.SEND_MY_CHAT_MESSAGE,
            deserializer = SendChatMessageGraphQLResponse.serializer(),
            variables = graphQLVariables("input" to input),
            operationName = "SendMyChatMessage",
            json = json,
        )
        return response.sendMyChatMessage.message
    }

    public suspend fun removeMyChatMessage(id: String) {
        client.graphQL(
            query = Documents.REMOVE_MY_CHAT_MESSAGE,
            deserializer = RemoveChatMessageGraphQLResponse.serializer(),
            variables = graphQLVariables("messageId" to id.lowercase()),
            operationName = "RemoveMyChatMessage",
            json = json,
        )
    }

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

    public object Documents {
        private const val MONEY_FIELDS = "cents currency"
        private const val TAG_FIELDS = "id name color"
        private const val LOCALE_FIELDS = "id name label cityNames bannerUrl"
        private const val ORGANIZER_FIELDS = "id name avatarUrl"
        private const val SOCIAL_LINK_FIELDS = "id handle provider url"
        private const val OFFER_FIELDS = "price { $MONEY_FIELDS } url seller { key name }"

        private const val COVER_CHARGE_FIELDS =
            "amount { $MONEY_FIELDS } fee { $MONEY_FIELDS } total { $MONEY_FIELDS } night from payable event { id name }"

        private const val ADMISSION_FIELDS =
            "id status night amount { $MONEY_FIELDS } total { $MONEY_FIELDS } isRefundable passSecret scanCount checkedInAt " +
                "profile { id name avatarUrl } venue { id name photoUrl } event { id name }"

        public const val CHAT_MESSAGE_FIELDS: String =
            "id message body name userId avatarUrl sentAt role kind title pinned"

        private const val EVENT_SUMMARY_FIELDS = """
            id name description startAt endAt isFeatured isCanceled bannerUrl sourceUrl
            locale { $LOCALE_FIELDS }
            tags { $TAG_FIELDS }
            rsvp { mine count }
            people {
              hosts { nodes { $ORGANIZER_FIELDS } }
              lineup { nodes { $ORGANIZER_FIELDS } }
            }
            tickets {
              url
              offers { nodes { $OFFER_FIELDS } }
              cover { charge { $COVER_CHARGE_FIELDS } }
            }
            venue {
              name
              venue {
                id name photoUrl
                location { id address point }
              }
            }
        """

        public const val UPCOMING_EVENTS: String = """
            query UpcomingEvents(${'$'}localeId: ID, ${'$'}venueId: ID) {
              events {
                list(localeId: ${'$'}localeId, venueId: ${'$'}venueId, window: UPCOMING, first: 50) {
                  nodes {
                    $EVENT_SUMMARY_FIELDS
                  }
                }
              }
            }
        """

        public const val EVENT_DETAIL: String = """
            query EventDetail(${'$'}id: ID!) {
              events {
                event(id: ${'$'}id) {
                  $EVENT_SUMMARY_FIELDS
                }
              }
            }
        """

        public const val VENUE_DETAIL: String = """
            query VenueDetail(${'$'}id: ID!) {
              venues {
                venue(id: ${'$'}id) {
                  id name description hidden order photoUrl bannerUrl
                  profile {
                    address phone
                    facebook { page { id name photoUrl bannerUrl } }
                    socialLinks { nodes { $SOCIAL_LINK_FIELDS } }
                  }
                  locale { $LOCALE_FIELDS }
                  location { id point address places { placeId } }
                  tags { $TAG_FIELDS }
                  chat {
                    open
                    recentMessages(limit: 5) {
                      nodes { $CHAT_MESSAGE_FIELDS }
                    }
                  }
                  events {
                    upcoming(first: 20) {
                      nodes { $EVENT_SUMMARY_FIELDS }
                    }
                  }
                  tickets {
                    offers { nodes { $OFFER_FIELDS } }
                    cover {
                      charge { $COVER_CHARGE_FIELDS }
                      viewerAdmission { $ADMISSION_FIELDS }
                    }
                  }
                }
              }
            }
        """

        public const val SEND_MY_CHAT_MESSAGE: String = """
            mutation SendMyChatMessage(${'$'}input: ChatMessageSendOwnInput!) {
              sendMyChatMessage(input: ${'$'}input) {
                message { $CHAT_MESSAGE_FIELDS }
              }
            }
        """

        public const val REMOVE_MY_CHAT_MESSAGE: String = """
            mutation RemoveMyChatMessage(${'$'}messageId: ID!) {
              removeMyChatMessage(input: { messageId: ${'$'}messageId }) {
                deletedId
              }
            }
        """

        public fun chatRoomSubscription(room: ChatRoomTarget, watch: Boolean = false): String {
            val watchArg = if (watch) ", watch: true" else ""
            return """
                subscription ChatRoom(${'$'}id: ID!) {
                  room: ${room.subscriptionField}(${room.argumentName}: ${'$'}id$watchArg) {
                    __typename
                    ... on ChatJoined {
                      outOfRange
                      roster {
                        people { userId name avatarUrl friend }
                      }
                      history { message { $CHAT_MESSAGE_FIELDS } }
                      pinnedMessage { message { $CHAT_MESSAGE_FIELDS } }
                    }
                    ... on ChatMessagePosted {
                      message { $CHAT_MESSAGE_FIELDS }
                    }
                    ... on ChatMessageUpdated {
                      message { $CHAT_MESSAGE_FIELDS }
                    }
                    ... on ChatMessageRemoved {
                      messageId
                    }
                    ... on ChatPinChanged {
                      messageId
                      pinned
                      announcement { $CHAT_MESSAGE_FIELDS }
                    }
                    ... on ChatRoomCleared {
                      clearedAt
                    }
                    ... on ChatPresenceChanged {
                      userId
                      presence
                      name
                      avatarUrl
                    }
                    ... on ChatRangeChanged {
                      outOfRange
                    }
                    ... on ChatLeft {
                      reason
                    }
                  }
                }
            """.trimIndent()
        }
    }
}

@Serializable
internal data class WireNodes<T>(
    val nodes: List<T?>? = null,
) {
    val items: List<T> get() = nodes.orEmpty().filterNotNull()
}

@Serializable
internal data class UpcomingEventsGraphQLResponse(
    val events: EventsMixin? = null,
) {
    @Serializable
    data class EventsMixin(val list: WireNodes<EventWire> = WireNodes())
}

@Serializable
internal data class EventDetailGraphQLResponse(
    val events: EventsMixin? = null,
) {
    @Serializable
    data class EventsMixin(val event: EventWire? = null)
}

@Serializable
internal data class EventWire(
    val id: String,
    val name: String? = null,
    val description: String? = null,
    val startAt: String? = null,
    val endAt: String? = null,
    val isFeatured: Boolean? = null,
    val isCanceled: Boolean? = null,
    val bannerUrl: String? = null,
    val sourceUrl: String? = null,
    val locale: AudienceLocale? = null,
    val tags: List<Tag>? = null,
    val rsvp: RsvpMixin? = null,
    val people: PeopleMixin? = null,
    val tickets: TicketsMixin? = null,
    val venue: VenueMixin? = null,
) {
    @Serializable
    data class RsvpMixin(val mine: RSVPState? = null, val count: Int? = null)

    @Serializable
    data class PeopleMixin(
        val hosts: WireNodes<EventOrganizer>? = null,
        val lineup: WireNodes<EventOrganizer>? = null,
    )

    @Serializable
    data class CoverMixin(val charge: CoverCharge? = null)

    @Serializable
    data class TicketsMixin(
        val url: String? = null,
        val offers: WireNodes<TicketOffer>? = null,
        val cover: CoverMixin? = null,
    )

    @Serializable
    data class VenueLocationWire(val id: String, val address: String? = null)

    @Serializable
    data class InnerVenueWire(
        val id: String,
        val name: String? = null,
        val photoUrl: String? = null,
        val location: VenueLocationWire? = null,
    )

    @Serializable
    data class VenueMixin(val name: String? = null, val venue: InnerVenueWire? = null)

    fun toConferenceEvent(): ConferenceEvent {
        val venueSummary = venue?.venue?.let {
            EventVenueSummary(
                id = it.id,
                name = it.name ?: venue.name ?: "Venue",
                photoUrl = it.photoUrl,
                address = it.location?.address,
            )
        }
        return ConferenceEvent(
            id = id,
            name = name ?: "Untitled Event",
            description = description,
            startAt = startAt,
            endAt = endAt,
            isFeatured = isFeatured ?: false,
            isCanceled = isCanceled ?: false,
            bannerUrl = bannerUrl,
            sourceUrl = sourceUrl,
            venueDisplayName = venue?.name ?: venueSummary?.name ?: "To be announced",
            venue = venueSummary,
            locale = locale,
            tags = tags.orEmpty(),
            rsvpState = rsvp?.mine ?: RSVPState.UNSURE,
            rsvpCount = rsvp?.count ?: 0,
            hosts = people?.hosts?.items.orEmpty(),
            lineup = people?.lineup?.items.orEmpty(),
            ticketUrl = tickets?.url,
            ticketOffers = tickets?.offers?.items.orEmpty(),
            coverCharge = tickets?.cover?.charge,
        )
    }
}

@Serializable
internal data class VenueDetailGraphQLResponse(
    val venues: VenuesMixin? = null,
) {
    @Serializable
    data class VenuesMixin(val venue: VenueDetailWire? = null)
}

@Serializable
internal data class VenueDetailWire(
    val id: String,
    val name: String? = null,
    val description: String? = null,
    val hidden: Boolean = false,
    val order: Int = 0,
    val photoUrl: String? = null,
    val bannerUrl: String? = null,
    val profile: ProfileMixin? = null,
    val locale: AudienceLocale,
    val location: com.audiencekit.Location? = null,
    val tags: List<Tag> = emptyList(),
    val chat: ChatMixin? = null,
    val events: EventsMixin? = null,
    val tickets: TicketsMixin? = null,
) {
    @Serializable
    data class ProfileMixin(
        val address: String? = null,
        val phone: String? = null,
        val facebook: com.audiencekit.FacebookProfile? = null,
        val socialLinks: WireNodes<SocialLink>? = null,
    )

    @Serializable
    data class ChatMixin(
        val open: Boolean? = null,
        val recentMessages: WireNodes<ChatMessageItem>? = null,
    )

    @Serializable
    data class EventsMixin(val upcoming: WireNodes<EventWire>? = null)

    @Serializable
    data class CoverMixin(
        val charge: CoverCharge? = null,
        val viewerAdmission: Admission? = null,
    )

    @Serializable
    data class TicketsMixin(
        val offers: WireNodes<TicketOffer>? = null,
        val cover: CoverMixin? = null,
    )

    fun toVenueDetail(): VenueDetail {
        val baseVenue = Venue(
            id = id,
            hidden = hidden,
            order = order,
            photoUrl = photoUrl,
            bannerUrl = bannerUrl,
            profile = com.audiencekit.ListingProfile(facebook = profile?.facebook),
            locale = locale,
            location = location,
            venueName = name,
            tags = tags,
        )
        return VenueDetail(
            venue = baseVenue,
            description = description,
            address = profile?.address ?: location?.address,
            phone = profile?.phone,
            socialLinks = profile?.socialLinks?.items.orEmpty(),
            chatOpen = chat?.open ?: false,
            recentMessages = chat?.recentMessages?.items.orEmpty(),
            upcomingEvents = events?.upcoming?.items.orEmpty().map { it.toConferenceEvent() },
            ticketOffers = tickets?.offers?.items.orEmpty(),
            coverCharge = tickets?.cover?.charge,
            viewerAdmission = tickets?.cover?.viewerAdmission,
        )
    }
}

@Serializable
internal data class SendChatMessageGraphQLResponse(
    val sendMyChatMessage: Payload,
) {
    @Serializable
    data class Payload(val message: ChatMessageItem)
}

@Serializable
internal data class RemoveChatMessageGraphQLResponse(
    val removeMyChatMessage: Payload,
) {
    @Serializable
    data class Payload(val deletedId: String? = null)
}

@Serializable
public data class RoomEventWire(
    @SerialName("__typename") val typename: String? = null,
    val outOfRange: Boolean? = null,
    val roster: RosterWire? = null,
    val history: List<PostedWire>? = null,
    val pinnedMessage: PostedWire? = null,
    val message: ChatMessageItem? = null,
    val announcement: ChatMessageItem? = null,
    val messageId: String? = null,
    val pinned: Boolean? = null,
    val userId: String? = null,
    val presence: String? = null,
    val name: String? = null,
    val avatarUrl: String? = null,
    val reason: String? = null,
) {
    @Serializable
    public data class RosterWire(val people: List<ChatParticipant>? = null)

    @Serializable
    public data class PostedWire(val message: ChatMessageItem? = null)
}

@Serializable
public data class RoomSubscriptionData(
    val room: RoomEventWire? = null,
)
