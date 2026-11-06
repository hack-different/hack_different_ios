//
//  VenuesScreen.swift
//  HackDifferent
//

import AudienceKit
import SwiftUI

struct VenuesScreen: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedCategory: SpaceCategory = .all
    @State private var searchText = ""

    private var filteredVenues: [Venue] {
        appModel.venues.filter { venue in
            let category = SpaceCategory.classify(tags: venue.tags, name: venue.name)
            if selectedCategory != .all && category != selectedCategory {
                return false
            }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matchesName = venue.name.lowercased().contains(query)
                let matchesLocale = (venue.locale.name ?? venue.locale.label ?? "").lowercased().contains(query)
                let matchesAddress = (venue.location?.address ?? "").lowercased().contains(query)
                let matchesTag = (venue.tags ?? []).contains { $0.name.lowercased().contains(query) }
                if !matchesName && !matchesLocale && !matchesAddress && !matchesTag {
                    return false
                }
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Space Category", selection: $selectedCategory) {
                        ForEach(SpaceCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                if appModel.isLoadingCatalog && appModel.venues.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading hackerspaces & conference venues…")
                            Spacer()
                        }
                        .padding(.vertical, 32)
                    }
                } else if filteredVenues.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Hackerspaces or Venues Found",
                            systemImage: selectedCategory.systemImage,
                            description: Text("Pull to refresh or adjust your search filter.")
                        )
                        .padding(.vertical, 24)
                    }
                } else {
                    Section("\(filteredVenues.count) Spaces & Venues") {
                        ForEach(filteredVenues) { venue in
                            NavigationLink(value: venue) {
                                VenueRowView(venue: venue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Spaces")
            .searchable(text: $searchText, prompt: "Search hackerspaces, con venues, cities…")
            .refreshable {
                await appModel.refreshCatalog()
            }
            .navigationDestination(for: Venue.self) { venue in
                VenueDetailScreen(venueID: venue.id, initialName: venue.name, initialVenue: venue)
            }
        }
    }
}

struct VenueRowView: View {
    let venue: Venue

    private var category: SpaceCategory {
        SpaceCategory.classify(tags: venue.tags, name: venue.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(
                    category == .conferenceVenue ? "Con Venue" : "Hackerspace",
                    systemImage: category.systemImage
                )
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(category == .conferenceVenue ? Color.indigo.opacity(0.16) : Color.teal.opacity(0.16))
                )
                .foregroundStyle(category == .conferenceVenue ? .indigo : .teal)

                if let localeName = venue.locale.name ?? venue.locale.label {
                    Text(localeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(venue.name)
                .font(.headline)

            if let address = venue.location?.address, !address.isEmpty {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let tags = venue.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags) { tag in
                            Text("#\(tag.name)")
                                .font(.caption2.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(.tertiarySystemFill)))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
