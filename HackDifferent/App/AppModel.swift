//
//  AppModel.swift
//  HackDifferent
//

import AudienceKit
import AudienceKitUI
import Foundation
import Observation

/// Composition root for Hack Different.
/// Holds the `AudienceKitClient`, `AudienceCable`, `BrandStore`, `SessionStore`, and shared data state.
@MainActor
@Observable
public final class AppModel {
    public enum Tab: Hashable, Sendable {
        case events
        case spaces
        case chat
        case passes
        case profile
    }

    public let configuration: AppConfiguration
    public let client: AudienceKitClient
    public let cable: AudienceCable
    public let api: HackDifferentAPI
    public let brand: BrandStore
    public let session: SessionStore

    public var selectedTab: Tab = .events

    public private(set) var venues: [Venue] = []
    public private(set) var events: [ConferenceEvent] = []
    public private(set) var locales: [AudienceLocale] = []
    public private(set) var admissions: [Admission] = []
    public private(set) var isLoadingCatalog = false
    public private(set) var catalogError: String?

    public init(
        configuration: AppConfiguration = .fromBundle(),
        credentialStore: any CredentialStore = SessionStore.credentialStore
    ) {
        self.configuration = configuration
        let client = AudienceKitClient(
            configuration: configuration.audienceKitConfiguration,
            credentialStore: credentialStore
        )
        self.client = client
        self.cable = client.makeCable()
        let api = HackDifferentAPI(client: client, configuration: configuration)
        self.api = api
        self.brand = BrandStore(client: client)
        self.session = SessionStore(client: client, api: api, configuration: configuration)

        AudienceUpdates.configure(session: client, appName: "Hack Different")
    }

    public func start() async {
        async let brandingTask: Void = brand.loadBranding()
        async let sessionTask: Void = session.start()
        _ = await (brandingTask, sessionTask)

        if session.isSignedIn {
            await refreshCatalog()
        }
    }

    public func refreshCatalog() async {
        guard !isLoadingCatalog else { return }
        isLoadingCatalog = true
        catalogError = nil
        defer { isLoadingCatalog = false }

        do {
            async let fetchedVenues = api.venues()
            async let fetchedEvents = api.upcomingEvents()
            async let fetchedLocales = api.locales()
            async let fetchedAdmissions = try? api.admissions()

            let (v, e, l, a) = try await (fetchedVenues, fetchedEvents, fetchedLocales, fetchedAdmissions)
            venues = v.filter { !$0.hidden }
            events = e.filter { !$0.isCanceled }
            locales = l
            admissions = a ?? []
        } catch let error as AudienceKitError {
            catalogError = error.message
        } catch {
            catalogError = error.localizedDescription
        }
    }

    public func refreshAdmissions() async {
        if let updated = try? await api.admissions() {
            admissions = updated
        }
    }

    public func updateEventRSVP(_ state: RSVPState, for eventID: String) async throws {
        let confirmed = try await api.setRSVP(state, forEvent: eventID)
        if let index = events.firstIndex(where: { $0.id == eventID }) {
            let previous = events[index].rsvpState
            events[index].rsvpState = confirmed
            if previous != .attending && confirmed == .attending {
                events[index].rsvpCount += 1
            } else if previous == .attending && confirmed != .attending {
                events[index].rsvpCount = max(0, events[index].rsvpCount - 1)
            }
        }
    }
}
