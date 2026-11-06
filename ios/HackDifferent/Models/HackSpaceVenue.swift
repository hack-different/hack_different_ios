//
//  HackSpaceVenue.swift
//  HackDifferent
//

import AudienceKit
import Foundation

/// Categorizes a venue in Hack Different as a Hackerspace or Conference Venue.
public enum SpaceCategory: String, CaseIterable, Sendable, Identifiable {
    case all = "All Spaces"
    case hackerspace = "Hackerspaces"
    case conferenceVenue = "Con Venues"

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

/// A ticket or admission offer returned by `tickets { offers { nodes { ... } } }`.
public struct TicketOffer: Codable, Hashable, Sendable, Identifiable {
    public struct Seller: Codable, Hashable, Sendable {
        public let key: String
        public let name: String

        public init(key: String, name: String) {
            self.key = key
            self.name = name
        }
    }

    public var id: String { "\(seller.key)-\(url?.absoluteString ?? "in-app")-\(price?.cents ?? 0)" }
    public let price: Money?
    public let seller: Seller
    public let url: URL?

    public init(price: Money? = nil, seller: Seller, url: URL? = nil) {
        self.price = price
        self.seller = seller
        self.url = url
    }

    enum CodingKeys: String, CodingKey {
        case price, seller, url
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        price = try container.decodeIfPresent(Money.self, forKey: .price)
        seller = try container.decode(Seller.self, forKey: .seller)
        if let rawURL = try container.decodeIfPresent(String.self, forKey: .url), !rawURL.isEmpty {
            url = URL(string: rawURL)
        } else {
            url = nil
        }
    }
}

/// Rich detail for a Hackerspace or Conference Venue, combining `AudienceKit.Venue`
/// with its upcoming conferences/meetups, live chat status, Discord links, and ticketing.
public struct VenueDetail: Sendable, Hashable, Identifiable {
    public let venue: Venue
    public let description: String?
    public let address: String?
    public let phone: String?
    public let socialLinks: [SocialLink]
    public let chatOpen: Bool
    public let recentMessages: [ChatMessageItem]
    public let upcomingEvents: [ConferenceEvent]
    public let ticketOffers: [TicketOffer]
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
        recentMessages: [ChatMessageItem] = [],
        upcomingEvents: [ConferenceEvent] = [],
        ticketOffers: [TicketOffer] = [],
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
