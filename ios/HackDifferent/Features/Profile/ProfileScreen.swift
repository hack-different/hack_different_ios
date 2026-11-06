//
//  ProfileScreen.swift
//  HackDifferent
//

import AudienceKit
import SwiftUI

struct ProfileScreen: View {
    @Environment(AppModel.self) private var appModel

    private var attendingEvents: [ConferenceEvent] {
        appModel.events.filter { $0.rsvpState == .attending || $0.rsvpState == .maybe }
    }

    var body: some View {
        NavigationStack {
            List {
                // Signed-In Hacker Profile
                Section("Account") {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.18))
                                .frame(width: 52, height: 52)
                            Image(systemName: "person.crop.circle.fill.badge.checkmark")
                                .font(.title2)
                                .foregroundStyle(.tint)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appModel.session.currentUser?.name ?? "Hack Different Member")
                                .font(.headline)
                            if let email = appModel.session.currentUser?.emailAddress {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if appModel.session.currentUser?.isAdmin == true {
                                Text("Audience Admin")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.teal.opacity(0.2)))
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // My RSVPs
                Section("My RSVPs (\(attendingEvents.count))") {
                    if attendingEvents.isEmpty {
                        Text("You haven't RSVPed to any upcoming conferences or meetups yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attendingEvents) { event in
                            NavigationLink {
                                EventDetailScreen(event: event)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(event.venueDisplayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(event.rsvpState == .attending ? "Going" : "Interested")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(event.rsvpState == .attending ? .green : .orange)
                                }
                            }
                        }
                    }
                }

                // AudienceKit Environment Details
                Section("AudienceKit Connection") {
                    LabeledContent("Audience", value: appModel.brand.audienceName)
                    LabeledContent("API", value: appModel.configuration.baseURL.host ?? appModel.configuration.baseURL.absoluteString)
                        .font(.caption.monospaced())
                    LabeledContent("Tenant", value: appModel.configuration.host)
                        .font(.caption.monospaced())
                    LabeledContent("Audience ID", value: appModel.configuration.audienceID)
                        .font(.caption2.monospaced())
                    LabeledContent("SDK Version", value: AudienceKitSDK.version)
                    LabeledContent("API Contract", value: AudienceKitSDK.apiVersion)
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await appModel.session.signOut()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profile")
            .refreshable {
                await appModel.session.refreshProfile()
                await appModel.refreshCatalog()
            }
        }
    }
}
