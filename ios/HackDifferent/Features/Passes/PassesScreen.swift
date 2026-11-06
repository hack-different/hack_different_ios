//
//  PassesScreen.swift
//  HackDifferent
//

import AudienceKit
import SwiftUI

struct PassesScreen: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL
    @State private var errorMessage: String?

    private var ticketedEvents: [ConferenceEvent] {
        appModel.events.filter(\.hasTicketing)
    }

    var body: some View {
        NavigationStack {
            List {
                // Active Passes
                Section {
                    if appModel.admissions.isEmpty {
                        ContentUnavailableView(
                            "No Passes Yet",
                            systemImage: "qrcode.viewfinder",
                            description: Text("Passes you purchase for conferences, meetups, and hackerspaces appear here with a live rotating QR code.")
                        )
                        .padding(.vertical, 16)
                    } else {
                        ForEach(appModel.admissions) { admission in
                            NavigationLink(value: admission) {
                                AdmissionRowView(admission: admission)
                            }
                        }
                    }
                } header: {
                    Text("My Passes (\(appModel.admissions.count))")
                }

                // Ticketed Conferences & Events
                if !ticketedEvents.isEmpty {
                    Section("Conferences & Events On Sale") {
                        ForEach(ticketedEvents) { event in
                            NavigationLink {
                                EventDetailScreen(event: event)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(event.venueDisplayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let price = event.lowestTicketPrice {
                                        Text(price.formattedAmount)
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(Color.accentColor.opacity(0.16)))
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Passes")
            .refreshable {
                await appModel.refreshAdmissions()
                await appModel.refreshCatalog()
            }
            .navigationDestination(for: Admission.self) { admission in
                PassQRCodeView(admission: admission)
            }
        }
    }
}

private struct AdmissionRowView: View {
    let admission: Admission

    private var statusColor: Color {
        switch admission.status {
        case .paid: .green
        case .pending: .orange
        case .refunded, .canceled: .secondary
        case .failed, .disputed: .red
        case .unknown: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "qrcode")
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(admission.event?.name ?? admission.venue.name ?? "Conference Pass")
                    .font(.headline)

                if let venueName = admission.venue.name, admission.event?.name != nil {
                    Text(venueName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(admission.night)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(admission.total.formattedAmount)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(admission.status.rawValue)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(statusColor.opacity(0.16)))
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 4)
    }
}
