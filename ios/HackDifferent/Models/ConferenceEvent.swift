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

/// Summary of the venue where a conference or meetup is hosted.
public struct EventVenueSummary: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let photoUrl: String?
    public let address: String?
    public let coordinate: Coordinate?

    public init(
        id: String,
        name: String,
        photoUrl: String? = nil,
        address: String? = nil,
        coordinate: Coordinate? = nil
    ) {
        self.id = id
        self.name = name
        self.photoUrl = photoUrl
        self.address = address
        self.coordinate = coordinate
    }

    init(_ venue: EventVenue, displayName: String?) {
        self.init(
            id: venue.id,
            name: venue.name ?? displayName ?? "Venue",
            photoUrl: venue.photoUrl,
            address: venue.location?.address,
            coordinate: venue.location?.coordinate
        )
    }
}

/// A conference or meetup event in the Hack Different audience.
public struct ConferenceEvent: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let startAt: Date?
    public let endAt: Date?
    public let recurrenceText: String?
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
    public let hosts: [EventPerson]
    public let lineup: [EventPerson]
    public let ticketURL: URL?
    public let ticketOffers: [AdmissionOffer]
    public let coverCharge: CoverCharge?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        startAt: Date? = nil,
        endAt: Date? = nil,
        recurrenceText: String? = nil,
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
        hosts: [EventPerson] = [],
        lineup: [EventPerson] = [],
        ticketURL: URL? = nil,
        ticketOffers: [AdmissionOffer] = [],
        coverCharge: CoverCharge? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startAt = startAt
        self.endAt = endAt
        self.recurrenceText = recurrenceText
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

    /// Maps an SDK ``Event`` into the view model.
    init(_ event: Event) {
        let venue = event.venue.map { EventVenueSummary($0, displayName: event.venueName) }
        self.init(
            id: event.id,
            name: event.name ?? "Untitled Event",
            description: event.description,
            startAt: event.startAt,
            endAt: event.endAt,
            isFeatured: event.isFeatured,
            isCanceled: event.isCanceled,
            bannerUrl: event.bannerUrl,
            sourceUrl: event.sourceUrl.flatMap(URL.init(string:)),
            venueDisplayName: event.venueName ?? venue?.name ?? event.locale?.name ?? event.locale?.label ?? "Hack Different",
            venue: venue,
            locale: event.locale,
            tags: event.tags ?? [],
            rsvpState: event.rsvp?.mine ?? .unsure,
            rsvpCount: event.rsvp?.count ?? 0,
            hosts: event.hosts ?? [],
            lineup: event.lineup ?? [],
            ticketURL: event.ticketURL,
            ticketOffers: event.ticketOffers ?? [],
            coverCharge: event.coverCharge
        )
    }

    /// Maps an SDK ``EventSeries`` (a recurring meetup) into the view model.
    init(_ series: EventSeries) {
        let venue = series.venue.map { EventVenueSummary($0, displayName: series.venueName) }
        let schedule: String? = {
            guard let recurrence = series.recurrenceText, !recurrence.isEmpty else { return series.startTime }
            return series.startTime.isEmpty ? recurrence : "\(recurrence) • \(series.startTime)"
        }()
        self.init(
            id: series.id,
            name: series.name,
            description: series.description,
            startAt: ISO8601.date(from: series.startsOn),
            recurrenceText: schedule,
            bannerUrl: series.bannerUrl,
            venueDisplayName: series.venueName ?? venue?.name ?? series.locale?.name ?? series.locale?.label ?? "Hack Different",
            venue: venue,
            locale: series.locale,
            tags: series.tags ?? []
        )
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
        ticketURL ?? ticketOffers.compactMap(\.webURL).first
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
