//
//  ConferenceEvent.swift
//  HackDifferent
//

import AudienceKit
import Foundation

/// Categorizes an event in Hack Different as a Conference or a Meetup.
public enum EventKind: String, CaseIterable, Sendable, Identifiable {
    case all = "All"
    case conference = "Conferences"
    case meetup = "Meetups"

    public var id: String { rawValue }

    public var badgeLabel: String {
        switch self {
        case .all: "Event"
        case .conference: "Conference"
        case .meetup: "Meetup"
        }
    }

    public var systemImage: String {
        switch self {
        case .all: "calendar"
        case .conference: "ticket.fill"
        case .meetup: "person.2.wave.2.fill"
        }
    }
}

/// Speaker, organizer, or host on a conference or meetup.
public struct EventOrganizer: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let avatarUrl: String?

    public init(id: String, name: String, avatarUrl: String? = nil) {
        self.id = id
        self.name = name
        self.avatarUrl = avatarUrl
    }
}

/// Summary of the venue where a conference or meetup is hosted.
public struct EventVenueSummary: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let photoUrl: String?
    public let address: String?

    public init(id: String, name: String, photoUrl: String? = nil, address: String? = nil) {
        self.id = id
        self.name = name
        self.photoUrl = photoUrl
        self.address = address
    }
}

/// A conference or meetup event in the Hack Different audience.
public struct ConferenceEvent: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let startAt: Date?
    public let endAt: Date?
    public let isFeatured: Bool
    public let isCanceled: Bool
    public let bannerUrl: String?
    public let sourceUrl: URL?
    public let venueDisplayName: String
    public let venue: EventVenueSummary?
    public let locale: AudienceLocale?
    public let tags: [Tag]
    public var rsvpState: RSVPState
    public var rsvpCount: Int
    public let hosts: [EventOrganizer]
    public let lineup: [EventOrganizer]
    public let ticketURL: URL?
    public let ticketOffers: [TicketOffer]
    public let coverCharge: CoverCharge?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        startAt: Date? = nil,
        endAt: Date? = nil,
        isFeatured: Bool = false,
        isCanceled: Bool = false,
        bannerUrl: String? = nil,
        sourceUrl: URL? = nil,
        venueDisplayName: String = "To be announced",
        venue: EventVenueSummary? = nil,
        locale: AudienceLocale? = nil,
        tags: [Tag] = [],
        rsvpState: RSVPState = .unsure,
        rsvpCount: Int = 0,
        hosts: [EventOrganizer] = [],
        lineup: [EventOrganizer] = [],
        ticketURL: URL? = nil,
        ticketOffers: [TicketOffer] = [],
        coverCharge: CoverCharge? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startAt = startAt
        self.endAt = endAt
        self.isFeatured = isFeatured
        self.isCanceled = isCanceled
        self.bannerUrl = bannerUrl
        self.sourceUrl = sourceUrl
        self.venueDisplayName = venueDisplayName
        self.venue = venue
        self.locale = locale
        self.tags = tags
        self.rsvpState = rsvpState
        self.rsvpCount = rsvpCount
        self.hosts = hosts
        self.lineup = lineup
        self.ticketURL = ticketURL
        self.ticketOffers = ticketOffers
        self.coverCharge = coverCharge
    }

    public var kind: EventKind {
        let tagNames = tags.map { $0.name.lowercased() }
        let loweredName = name.lowercased()
        if tagNames.contains(where: { $0.contains("con") || $0.contains("conference") || $0.contains("summit") || $0.contains("ctf") })
            || loweredName.contains("con") || loweredName.contains("conference") || loweredName.contains("summit") || loweredName.contains("bsides") || loweredName.contains("defcon") {
            return .conference
        }
        if let startAt, let endAt, endAt.timeIntervalSince(startAt) >= 8 * 3600 {
            return .conference
        }
        return .meetup
    }

    public var hasTicketing: Bool {
        ticketURL != nil || !ticketOffers.isEmpty || coverCharge != nil
    }

    public var primaryTicketURL: URL? {
        ticketURL ?? ticketOffers.compactMap(\.url).first
    }

    public var lowestTicketPrice: Money? {
        if let coverCharge {
            return coverCharge.total
        }
        return ticketOffers.compactMap(\.price).min(by: { $0.cents < $1.cents })
    }

    public var discordLink: DiscordChannelLink? {
        DiscordChannelLink.resolve(
            title: "\(name) Discord",
            description: description,
            sourceURL: sourceUrl
        )
    }
}
