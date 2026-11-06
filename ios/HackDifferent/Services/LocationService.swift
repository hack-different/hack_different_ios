//
//  LocationService.swift
//  HackDifferent
//

import AudienceKit
import CoreLocation
import Foundation
import Observation

/// Opt-in location service for surfacing location-specific events and hackerspaces
/// while keeping all events visible by default.
@MainActor
@Observable
public final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    /// Maximum distance (in meters) considered "nearby" (~50 miles / 80 km) when matching by coordinate.
    public static let nearbyThresholdMeters: Double = 80_000

    private let client: AudienceKitClient
    private let manager = CLLocationManager()
    private var pendingOptInRequest = false

    public private(set) var authorizationStatus: CLAuthorizationStatus
    public private(set) var currentCoordinate: Coordinate?
    public private(set) var closestLocale: AudienceLocale?
    public private(set) var isLocating = false
    public private(set) var locationError: String?

    public var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    public var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    public init(client: AudienceKitClient) {
        self.client = client
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Silently refreshes the user's location and closest locale only if permission was already granted.
    public func refreshIfAuthorized() {
        authorizationStatus = manager.authorizationStatus
        guard isAuthorized else { return }
        requestCurrentLocation()
    }

    /// Prompts for location permission (if not yet determined) or refreshes location immediately once opted in.
    public func requestOptIn() {
        authorizationStatus = manager.authorizationStatus
        locationError = nil

        switch authorizationStatus {
        case .notDetermined:
            pendingOptInRequest = true
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestCurrentLocation()
        case .denied, .restricted:
            locationError = "Location access is disabled in Settings."
        @unknown default:
            break
        }
    }

    private func requestCurrentLocation() {
        guard !isLocating else { return }
        isLocating = true
        locationError = nil
        manager.requestLocation()
    }

    /// Resolves a fallback closest locale from loaded venues/locales if the server doesn't return one.
    public func updateFallbackClosestLocale(venues: [Venue], locales: [AudienceLocale]) {
        guard closestLocale == nil, let currentCoordinate else { return }
        let userLocation = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)

        var nearestVenue: (venue: Venue, distance: CLLocationDistance)?
        for venue in venues {
            guard let coord = venue.location?.coordinate else { continue }
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let dist = userLocation.distance(from: loc)
            if nearestVenue == nil || dist < nearestVenue!.distance {
                nearestVenue = (venue, dist)
            }
        }

        if let candidate = nearestVenue, candidate.distance <= Self.nearbyThresholdMeters * 2 {
            closestLocale = locales.first(where: { $0.id == candidate.venue.locale.id }) ?? candidate.venue.locale
        }
    }

    public func distanceInMeters(to coordinate: Coordinate?) -> Double? {
        guard let currentCoordinate, let coordinate else { return nil }
        let from = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return from.distance(from: to)
    }

    public func formattedDistance(to coordinate: Coordinate?) -> String? {
        guard let meters = distanceInMeters(to: coordinate) else { return nil }
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let style = Measurement<UnitLength>.FormatStyle(
            width: .abbreviated,
            usage: .road,
            numberFormatStyle: .number.precision(.fractionLength(0...1))
        )
        return measurement.formatted(style)
    }

    public func isEventNearby(_ event: ConferenceEvent, venues: [Venue]) -> Bool {
        guard isAuthorized else { return false }
        if let closestID = closestLocale?.id, let eventLocaleID = event.locale?.id, closestID == eventLocaleID {
            return true
        }
        let coord = event.venue?.coordinate
            ?? venues.first(where: { $0.id == event.venue?.id })?.location?.coordinate
        if let meters = distanceInMeters(to: coord) {
            return meters <= Self.nearbyThresholdMeters
        }
        return false
    }

    public func isVenueNearby(_ venue: Venue) -> Bool {
        guard isAuthorized else { return false }
        if let closestID = closestLocale?.id, venue.locale.id == closestID {
            return true
        }
        if let meters = distanceInMeters(to: venue.location?.coordinate) {
            return meters <= Self.nearbyThresholdMeters
        }
        return false
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAuthorized {
            if pendingOptInRequest || currentCoordinate == nil {
                pendingOptInRequest = false
                isLocating = false
                requestCurrentLocation()
            }
        } else if isDenied {
            pendingOptInRequest = false
            isLocating = false
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else {
            isLocating = false
            return
        }
        let coordinate = Coordinate(
            latitude: latest.coordinate.latitude,
            longitude: latest.coordinate.longitude
        )
        currentCoordinate = coordinate

        Task { @MainActor in
            if let resolved = try? await client.closestLocale(near: coordinate) {
                self.closestLocale = resolved
            }
            self.isLocating = false
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        isLocating = false
        if let clError = error as? CLError, clError.code == .locationUnknown {
            return
        }
        locationError = error.localizedDescription
    }
}
