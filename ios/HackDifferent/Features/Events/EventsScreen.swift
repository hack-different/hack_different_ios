//
//  EventsScreen.swift
//  HackDifferent
//

import AudienceKit
import SwiftUI

struct EventsScreen: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedKind: EventKind = .all
    @State private var selectedLocaleID: String?
    @State private var searchText = ""

    private var filteredEvents: [ConferenceEvent] {
        appModel.events.filter { event in
            if selectedKind != .all && event.kind != selectedKind {
                return false
            }
            if let selectedLocaleID, event.locale?.id != selectedLocaleID {
                return false
            }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matchesName = event.name.lowercased().contains(query)
                let matchesVenue = event.venueDisplayName.lowercased().contains(query)
                let matchesTag = event.tags.contains { $0.name.lowercased().contains(query) }
                if !matchesName && !matchesVenue && !matchesTag {
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
                    Picker("Event Type", selection: $selectedKind) {
                        ForEach(EventKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)

                    if !appModel.locales.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(
                                    title: "All Regions",
                                    isSelected: selectedLocaleID == nil
                                ) {
                                    selectedLocaleID = nil
                                }
                                ForEach(appModel.locales) { locale in
                                    FilterChip(
                                        title: locale.name ?? locale.label ?? "Region",
                                        isSelected: selectedLocaleID == locale.id
                                    ) {
                                        selectedLocaleID = locale.id
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 8, trailing: 12))
                        .listRowBackground(Color.clear)
                    }
                }

                if appModel.isLoadingCatalog && appModel.events.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading conferences & meetups…")
                            Spacer()
                        }
                        .padding(.vertical, 32)
                    }
                } else if filteredEvents.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Conferences or Meetups Found",
                            systemImage: selectedKind.systemImage,
                            description: Text("Pull to refresh or adjust your filters to see upcoming Hack Different events.")
                        )
                        .padding(.vertical, 24)
                    }
                } else {
                    Section("\(filteredEvents.count) Upcoming") {
                        ForEach(filteredEvents) { event in
                            NavigationLink(value: event) {
                                EventRowView(event: event)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Conferences & Meetups")
            .searchable(text: $searchText, prompt: "Search cons, meetups, venues, tags…")
            .refreshable {
                await appModel.refreshCatalog()
            }
            .navigationDestination(for: ConferenceEvent.self) { event in
                EventDetailScreen(event: event)
            }
        }
    }
}

struct EventRowView: View {
    let event: ConferenceEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(event.kind.badgeLabel, systemImage: event.kind.systemImage)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(event.kind == .conference ? Color.purple.opacity(0.16) : Color.blue.opacity(0.16))
                    )
                    .foregroundStyle(event.kind == .conference ? .purple : .blue)

                if event.isFeatured {
                    Label("Featured", systemImage: "star.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Spacer()

                if event.rsvpState == .attending {
                    Label("Going", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else if event.rsvpState == .maybe {
                    Label("Interested", systemImage: "star.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            Text(event.name)
                .font(.headline)

            HStack(spacing: 12) {
                if let startAt = event.startAt {
                    Label(
                        startAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Label(event.venueDisplayName, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                if let lowestPrice = event.lowestTicketPrice {
                    Label("Tickets: \(lowestPrice.formattedAmount)", systemImage: "ticket.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tint)
                }

                if event.rsvpCount > 0 {
                    Label("\(event.rsvpCount) going", systemImage: "person.2.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if event.discordLink != nil {
                    Label("Discord", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
