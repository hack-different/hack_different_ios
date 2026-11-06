//
//  HackDifferentAPI.swift
//  HackDifferent
//

import AudienceKit
import Foundation

/// Hack Different's domain operations on top of `AudienceKitClient` (`AudienceSession`): the SDK's events and venue
/// pages mapped to the app's view models, plus what the SDK doesn't offer yet (ticket offers and event cover charges,
/// review sign-in).
public struct HackDifferentAPI: Sendable {
    public let client: AudienceKitClient
    public let configuration: AppConfiguration

    public init(client: AudienceKitClient, configuration: AppConfiguration) {
        self.client = client
        self.configuration = configuration
    }

    // MARK: - Venues (Hackerspaces & Conference Venues)

    public func venueDetail(id: String) async throws -> SpaceDetail {
        async let coverTask = try? client.venueCover(venueID: id)
        async let offersTask = try? client.venueOffers(venueID: id)
        guard let detail = try await client.venueDetail(id: id, recentMessages: 5) else {
            throw AudienceKitError.notFound
        }
        var events = (detail.upcomingEvents ?? []).map { ConferenceEvent($0) }
        if events.isEmpty, let venueEvents = try? await upcomingEvents(venueID: id) {
            events = venueEvents
        }
        return await SpaceDetail(detail, upcomingEvents: events, ticketOffers: offersTask ?? [], cover: coverTask)
    }

    // MARK: - Events (Conferences & Meetups)

    /// Upcoming events, then the recurring series that have no upcoming night listed under the same name.
    public func upcomingEvents(localeID: String? = nil, venueID: String? = nil) async throws -> [ConferenceEvent] {
        async let seriesTask = try? client.eventSeries(localeID: localeID, venueID: venueID)
        let events = try await client.events(window: .upcoming, localeID: localeID, venueID: venueID)

        var result = events.map { ConferenceEvent($0) }
        var listedNames = Set(result.map { $0.name.lowercased() })
        for series in await seriesTask ?? [] where !listedNames.contains(series.name.lowercased()) {
            listedNames.insert(series.name.lowercased())
            result.append(ConferenceEvent(series))
        }
        return result
    }

    public func eventDetail(id: String) async throws -> ConferenceEvent {
        guard let event = try await client.event(id: id) else {
            throw AudienceKitError.notFound
        }
        return ConferenceEvent(event)
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
