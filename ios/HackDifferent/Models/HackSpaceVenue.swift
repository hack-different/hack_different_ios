//
//  HackSpaceVenue.swift
//  HackDifferent
//

import AudienceKit
import Foundation

/// Categorizes a venue in Hack Different as a Hackerspace or Conference Venue.
public enum SpaceCategory: String, CaseIterable, Sendable, Identifiable {
    case all = "All"
    case hackerspace = "Hackerspaces"
    case conferenceVenue = "Venues"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .all: "building.2.crop.circle"
        case .hackerspace: "cpu.fill"
        case .conferenceVenue: "person.3.sequence.fill"
        }
    }

    public static func classify(tags: [Tag]?, name: String) -> SpaceCategory {
        let tagNames = (tags ?? []).map { $0.name.lowercased() }
        let loweredName = name.lowercased()
        if tagNames.contains(where: { $0.contains("con") || $0.contains("conference") || $0.contains("hotel") || $0.contains("center") })
            || loweredName.contains("con") || loweredName.contains("center") || loweredName.contains("convention") {
            return .conferenceVenue
        }
        return .hackerspace
    }
}

extension AdmissionOffer: @retroactive Identifiable {
    public var id: String { "\(seller.key)-\(url ?? "in-app")-\(price?.cents ?? 0)" }

    /// Where to buy it, when the seller sells on the web.
    public var webURL: URL? { url.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
}

/// Rich detail for a Hackerspace or Conference Venue: the SDK's ``VenueDetail`` with its events mapped to
/// ``ConferenceEvent``s, plus the venue's ticketing (offers, tonight's cover and the viewer's pass).
public struct SpaceDetail: Sendable, Hashable, Identifiable {
    public let venue: Venue
    public let description: String?
    public let address: String?
    public let phone: String?
    public let socialLinks: [SocialLink]
    public let chatOpen: Bool
    public let recentMessages: [ChatMessage]
    public let upcomingEvents: [ConferenceEvent]
    public let ticketOffers: [AdmissionOffer]
    public let coverCharge: CoverCharge?
    public let viewerAdmission: Admission?

    public var id: String { venue.id }
    public var name: String { venue.name }

    public var category: SpaceCategory {
        SpaceCategory.classify(tags: venue.tags, name: venue.name)
    }

    public var discordLink: DiscordChannelLink? {
        DiscordChannelLink.resolve(
            title: "\(venue.name) Discord",
            socialLinks: socialLinks,
            description: description
        )
    }

    public init(
        venue: Venue,
        description: String? = nil,
        address: String? = nil,
        phone: String? = nil,
        socialLinks: [SocialLink] = [],
        chatOpen: Bool = false,
        recentMessages: [ChatMessage] = [],
        upcomingEvents: [ConferenceEvent] = [],
        ticketOffers: [AdmissionOffer] = [],
        coverCharge: CoverCharge? = nil,
        viewerAdmission: Admission? = nil
    ) {
        self.venue = venue
        self.description = description
        self.address = address ?? venue.location?.address
        self.phone = phone
        self.socialLinks = socialLinks
        self.chatOpen = chatOpen
        self.recentMessages = recentMessages
        self.upcomingEvents = upcomingEvents
        self.ticketOffers = ticketOffers
        self.coverCharge = coverCharge
        self.viewerAdmission = viewerAdmission
    }
}

extension SpaceDetail {
    init(_ detail: VenueDetail, upcomingEvents: [ConferenceEvent], ticketOffers: [AdmissionOffer], cover: VenueCover?) {
        self.init(
            venue: detail.venue,
            description: detail.description,
            address: detail.address,
            phone: detail.phone,
            socialLinks: detail.socialLinks ?? [],
            chatOpen: detail.chatOpen ?? false,
            recentMessages: detail.recentMessages ?? [],
            upcomingEvents: upcomingEvents,
            ticketOffers: ticketOffers,
            coverCharge: cover?.coverCharge,
            viewerAdmission: cover?.viewerAdmission
        )
    }
}

extension Money {
    /// Formatted currency string (e.g. "$25.00" or "Free" when 0).
    public var formattedAmount: String {
        if cents == 0 {
            return "Free"
        }
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        return formatter.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
    }
}
