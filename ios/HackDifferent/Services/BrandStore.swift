//
//  BrandStore.swift
//  HackDifferent
//

import AudienceKit
import AudienceKitUI
import Observation
import SwiftUI

/// Fetches and caches public audience branding from `/v1/branding` for Hack Different.
@MainActor
@Observable
public final class BrandStore {
    public private(set) var branding: Branding?
    public private(set) var isLoading = false

    private let client: AudienceKitClient

    public init(client: AudienceKitClient) {
        self.client = client
    }

    public var audienceName: String {
        branding?.audience.name ?? "Hack Different"
    }

    public var tagline: String {
        branding?.theme.tagline ?? "Hackerspaces, Conferences, Meetups & Community"
    }

    public var preset: String {
        branding?.theme.preset ?? "default"
    }

    public func accentColor(for colorScheme: ColorScheme) -> Color {
        if let token = branding?.theme.color("accent", dark: colorScheme == .dark) {
            return Color(token)
        }
        return Color.accentColor
    }

    public func loadBranding() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            branding = try await client.branding(app: Bundle.main.bundleIdentifier)
        } catch {
            // Keep default Hack Different branding when offline
        }
    }
}
