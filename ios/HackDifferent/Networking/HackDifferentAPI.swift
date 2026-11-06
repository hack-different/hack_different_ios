//
//  HackDifferentAPI.swift
//  HackDifferent
//

import AudienceKit
import Foundation

/// Typed domain operations built on top of `AudienceKitClient` (`AudienceSession`).
public struct HackDifferentAPI: Sendable {
    public let client: AudienceKitClient
    public let configuration: AppConfiguration

    public init(client: AudienceKitClient, configuration: AppConfiguration) {
        self.client = client
        self.configuration = configuration
    }

    // MARK: - Venues (Hackerspaces & Conference Venues)

    public func venues() async throws -> [Venue] {
        try await client.venues()
    }

    public func locales() async throws -> [AudienceLocale] {
        try await client.locales()
    }

    public func venueDetail(id: String) async throws -> VenueDetail {
        let response = try await client.graphQL(
            Documents.venueDetail,
            variables: ["id": .string(id)],
            operationName: "VenueDetail",
            as: VenueDetailGraphQLResponse.self
        )
        guard let wire = response.venues?.venue else {
            throw AudienceKitError.notFound
        }
        return wire.toVenueDetail()
    }

    // MARK: - Events (Conferences & Meetups)

    public func upcomingEvents(localeID: String? = nil, venueID: String? = nil) async throws -> [ConferenceEvent] {
        var variables: [String: GraphQLValue] = [:]
        if let localeID { variables["localeId"] = .string(localeID) }
        if let venueID { variables["venueId"] = .string(venueID) }

        let response = try await client.graphQL(
            Documents.upcomingEvents,
            variables: variables.isEmpty ? nil : variables,
            operationName: "UpcomingEvents",
            as: UpcomingEventsGraphQLResponse.self
        )
        return (response.events?.list.items ?? []).map { $0.toConferenceEvent() }
    }

    public func eventDetail(id: String) async throws -> ConferenceEvent {
        let response = try await client.graphQL(
            Documents.eventDetail,
            variables: ["id": .string(id)],
            operationName: "EventDetail",
            as: EventDetailGraphQLResponse.self
        )
        guard let wire = response.events?.event else {
            throw AudienceKitError.notFound
        }
        return wire.toConferenceEvent()
    }

    @discardableResult
    public func setRSVP(_ state: RSVPState, forEvent eventID: String) async throws -> RSVPState {
        try await client.setRSVP(state, forEvent: eventID)
    }

    // MARK: - Ticketing & Passes

    public func admissions() async throws -> [Admission] {
        try await client.admissions()
    }

    public func venueCover(venueID: String) async throws -> VenueCover? {
        try await client.venueCover(venueID: venueID)
    }

    public func buyCover(venueID: String) async throws -> CoverPurchase {
        try await client.buyCover(venueID: venueID)
    }

    public func confirmCover(admissionID: String) async throws -> Admission {
        try await client.confirmCover(admissionID: admissionID)
    }

    public func refundAdmission(admissionID: String) async throws -> Admission {
        try await client.refundAdmission(admissionID: admissionID)
    }

    // MARK: - Chat

    @discardableResult
    public func sendChatMessage(_ text: String, in room: ChatRoomTarget) async throws -> ChatMessageItem {
        let input: [String: GraphQLValue] = [
            room.argumentName: .string(room.recordID.lowercased()),
            "message": .string(text),
        ]
        let response = try await client.graphQL(
            Documents.sendMyChatMessage,
            variables: ["input": .object(input)],
            operationName: "SendMyChatMessage",
            as: SendChatMessageGraphQLResponse.self
        )
        return response.sendMyChatMessage.message
    }

    public func removeMyChatMessage(id: String) async throws {
        _ = try await client.graphQL(
            Documents.removeMyChatMessage,
            variables: ["messageId": .string(id.lowercased())],
            operationName: "RemoveMyChatMessage",
            as: RemoveChatMessageGraphQLResponse.self
        )
    }

    // MARK: - App Review Sign-In Support

    public func isReviewSignInEnabled() async -> Bool {
        struct ReviewStatus: Decodable { let enabled: Bool? }
        let query = [URLQueryItem(name: "host", value: configuration.host)]
        let request = APIRequest(method: "GET", path: "/v1/token/review", queryItems: query, authenticated: false)
        guard let data = try? await client.data(for: request),
              let status = try? JSONDecoder.audienceKit.decode(ReviewStatus.self, from: data)
        else {
            return false
        }
        return status.enabled ?? false
    }

    public func signInWithReviewCode(_ code: String, device: DeviceDescription) async throws -> Credential {
        struct Payload: Encodable {
            let code: String
            let host: String
            let device: DeviceDescription
        }
        let body = try JSONEncoder().encode(Payload(code: code, host: configuration.host, device: device))
        let request = APIRequest(method: "POST", path: "/v1/token/review", body: body, authenticated: false)
        let data = try await client.data(for: request)
        let credential = try JSONDecoder.audienceKit.decode(Credential.self, from: data)
        try await client.adopt(credential: credential)
        return credential
    }
}

// MARK: - GraphQL Documents

extension HackDifferentAPI {
    public enum Documents {
        static let moneyFields = "cents currency"
        static let tagFields = "id name color"
        static let localeFields = "id name label cityNames bannerUrl"
        static let organizerFields = "id name avatarUrl"
        static let socialLinkFields = "id handle provider url"
        static let offerFields = "price { \(moneyFields) } url seller { key name }"

        static let coverChargeFields = """
        amount { \(moneyFields) } fee { \(moneyFields) } total { \(moneyFields) } night from payable event { id name }
        """

        static let admissionFields = """
        id status night amount { \(moneyFields) } total { \(moneyFields) } isRefundable passSecret scanCount checkedInAt \
        profile { id name avatarUrl } venue { id name photoUrl } event { id name }
        """

        public static let chatMessageFields = """
        id message body name userId avatarUrl sentAt role kind title pinned
        """

        static let eventSummaryFields = """
        id name description startAt endAt isFeatured isCanceled bannerUrl sourceUrl
        locale { \(localeFields) }
        tags { \(tagFields) }
        rsvp { mine count }
        people {
          hosts { nodes { \(organizerFields) } }
          lineup { nodes { \(organizerFields) } }
        }
        tickets {
          url
          offers { nodes { \(offerFields) } }
          cover { charge { \(coverChargeFields) } }
        }
        venue {
          name
          venue {
            id name photoUrl
            location { id address point }
          }
        }
        """

        public static let upcomingEvents = """
        query UpcomingEvents($localeId: ID, $venueId: ID) {
          events {
            list(localeId: $localeId, venueId: $venueId, window: UPCOMING, first: 50) {
              nodes {
                \(eventSummaryFields)
              }
            }
          }
        }
        """

        public static let eventDetail = """
        query EventDetail($id: ID!) {
          events {
            event(id: $id) {
              \(eventSummaryFields)
            }
          }
        }
        """

        public static let venueDetail = """
        query VenueDetail($id: ID!) {
          venues {
            venue(id: $id) {
              id name description hidden order photoUrl bannerUrl
              profile {
                address phone
                facebook { page { id name photoUrl bannerUrl } }
                socialLinks { nodes { \(socialLinkFields) } }
              }
              locale { \(localeFields) }
              location { id point address places { placeId } }
              tags { \(tagFields) }
              chat {
                open
                recentMessages(limit: 5) {
                  nodes { \(chatMessageFields) }
                }
              }
              events {
                upcoming(first: 20) {
                  nodes { \(eventSummaryFields) }
                }
              }
              tickets {
                offers { nodes { \(offerFields) } }
                cover {
                  charge { \(coverChargeFields) }
                  viewerAdmission { \(admissionFields) }
                }
              }
            }
          }
        }
        """

        public static let sendMyChatMessage = """
        mutation SendMyChatMessage($input: ChatMessageSendOwnInput!) {
          sendMyChatMessage(input: $input) {
            message { \(chatMessageFields) }
          }
        }
        """

        public static let removeMyChatMessage = """
        mutation RemoveMyChatMessage($messageId: ID!) {
          removeMyChatMessage(input: { messageId: $messageId }) {
            deletedId
          }
        }
        """
    }
}

// MARK: - Wire Decodables

private struct WireNodes<Element: Decodable & Sendable>: Decodable, Sendable {
    var nodes: [Element?]?
    var items: [Element] { (nodes ?? []).compactMap { $0 } }
}

private struct UpcomingEventsGraphQLResponse: Decodable, Sendable {
    struct EventsMixin: Decodable, Sendable {
        var list: WireNodes<EventWire>
    }
    var events: EventsMixin?
}

private struct EventDetailGraphQLResponse: Decodable, Sendable {
    struct EventsMixin: Decodable, Sendable {
        var event: EventWire?
    }
    var events: EventsMixin?
}

private struct EventWire: Decodable, Sendable {
    struct RSVPMixin: Decodable, Sendable {
        var mine: RSVPState?
        var count: Int?
    }
    struct PeopleMixin: Decodable, Sendable {
        var hosts: WireNodes<EventOrganizer>?
        var lineup: WireNodes<EventOrganizer>?
    }
    struct CoverMixin: Decodable, Sendable {
        var charge: CoverCharge?
    }
    struct TicketsMixin: Decodable, Sendable {
        var url: String?
        var offers: WireNodes<TicketOffer>?
        var cover: CoverMixin?
    }
    struct VenueLocationWire: Decodable, Sendable {
        var id: String
        var address: String?
    }
    struct InnerVenueWire: Decodable, Sendable {
        var id: String
        var name: String?
        var photoUrl: String?
        var location: VenueLocationWire?
    }
    struct VenueMixin: Decodable, Sendable {
        var name: String?
        var venue: InnerVenueWire?
    }

    var id: String
    var name: String?
    var description: String?
    var startAt: String?
    var endAt: String?
    var isFeatured: Bool?
    var isCanceled: Bool?
    var bannerUrl: String?
    var sourceUrl: String?
    var locale: AudienceLocale?
    var tags: [Tag]?
    var rsvp: RSVPMixin?
    var people: PeopleMixin?
    var tickets: TicketsMixin?
    var venue: VenueMixin?

    func toConferenceEvent() -> ConferenceEvent {
        let venueSummary: EventVenueSummary? = venue?.venue.map {
            EventVenueSummary(
                id: $0.id,
                name: $0.name ?? venue?.name ?? "Venue",
                photoUrl: $0.photoUrl,
                address: $0.location?.address
            )
        }
        return ConferenceEvent(
            id: id,
            name: name ?? "Untitled Event",
            description: description,
            startAt: startAt.flatMap(ISO8601.date(from:)),
            endAt: endAt.flatMap(ISO8601.date(from:)),
            isFeatured: isFeatured ?? false,
            isCanceled: isCanceled ?? false,
            bannerUrl: bannerUrl,
            sourceUrl: sourceUrl.flatMap(URL.init(string:)),
            venueDisplayName: venue?.name ?? venueSummary?.name ?? "To be announced",
            venue: venueSummary,
            locale: locale,
            tags: tags ?? [],
            rsvpState: rsvp?.mine ?? .unsure,
            rsvpCount: rsvp?.count ?? 0,
            hosts: people?.hosts?.items ?? [],
            lineup: people?.lineup?.items ?? [],
            ticketURL: tickets?.url.flatMap(URL.init(string:)),
            ticketOffers: tickets?.offers?.items ?? [],
            coverCharge: tickets?.cover?.charge
        )
    }
}

private struct VenueDetailGraphQLResponse: Decodable, Sendable {
    struct VenuesMixin: Decodable, Sendable {
        var venue: VenueDetailWire?
    }
    var venues: VenuesMixin?
}

private struct VenueDetailWire: Decodable, Sendable {
    struct ProfileMixin: Decodable, Sendable {
        var address: String?
        var phone: String?
        var socialLinks: WireNodes<SocialLink>?
    }
    struct ChatMixin: Decodable, Sendable {
        var open: Bool?
        var recentMessages: WireNodes<ChatMessageItem>?
    }
    struct EventsMixin: Decodable, Sendable {
        var upcoming: WireNodes<EventWire>?
    }
    struct CoverMixin: Decodable, Sendable {
        var charge: CoverCharge?
        var viewerAdmission: Admission?
    }
    struct TicketsMixin: Decodable, Sendable {
        var offers: WireNodes<TicketOffer>?
        var cover: CoverMixin?
    }

    let baseVenue: Venue
    let description: String?
    let profile: ProfileMixin?
    let chat: ChatMixin?
    let events: EventsMixin?
    let tickets: TicketsMixin?

    enum CodingKeys: String, CodingKey {
        case description, profile, chat, events, tickets
    }

    init(from decoder: any Decoder) throws {
        baseVenue = try Venue(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        profile = try container.decodeIfPresent(ProfileMixin.self, forKey: .profile)
        chat = try container.decodeIfPresent(ChatMixin.self, forKey: .chat)
        events = try container.decodeIfPresent(EventsMixin.self, forKey: .events)
        tickets = try container.decodeIfPresent(TicketsMixin.self, forKey: .tickets)
    }

    func toVenueDetail() -> VenueDetail {
        VenueDetail(
            venue: baseVenue,
            description: description,
            address: profile?.address ?? baseVenue.location?.address,
            phone: profile?.phone,
            socialLinks: profile?.socialLinks?.items ?? [],
            chatOpen: chat?.open ?? false,
            recentMessages: chat?.recentMessages?.items ?? [],
            upcomingEvents: (events?.upcoming?.items ?? []).map { $0.toConferenceEvent() },
            ticketOffers: tickets?.offers?.items ?? [],
            coverCharge: tickets?.cover?.charge,
            viewerAdmission: tickets?.cover?.viewerAdmission
        )
    }
}

private struct SendChatMessageGraphQLResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        var message: ChatMessageItem
    }
    var sendMyChatMessage: Payload
}

private struct RemoveChatMessageGraphQLResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        var deletedId: String?
    }
    var removeMyChatMessage: Payload
}
