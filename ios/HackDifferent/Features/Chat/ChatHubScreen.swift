//
//  ChatHubScreen.swift
//  HackDifferent
//

import AudienceKit
import SwiftUI

struct ChatHubScreen: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL
    @State private var customDiscordInvite = ""
    @State private var showingDiscordPrompt = false

    private var eventDiscordLinks: [DiscordChannelLink] {
        appModel.events.compactMap(\.discordLink)
    }

    var body: some View {
        NavigationStack {
            List {
                // Discord Community Integration
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.indigo.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.title3)
                                    .foregroundStyle(.indigo)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hack Different on Discord")
                                    .font(.headline)
                                Text("Connect with hackerspaces, conferences, and meetup channels on Discord.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                if let url = URL(string: "https://discord.com/app") {
                                    openURL(url)
                                }
                            } label: {
                                Label("Open Discord", systemImage: "arrow.up.right.square.fill")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)

                            Button {
                                showingDiscordPrompt = true
                            } label: {
                                Label("Join Invite Code", systemImage: "link.badge.plus")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)

                    ForEach(eventDiscordLinks) { link in
                        Button {
                            openURL(link.webURL)
                        } label: {
                            HStack {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(link.title)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text(link.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: "number")
                                        .foregroundStyle(.indigo)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Discord Channels")
                }

                // Venue & Con Live Chat Rooms (AudienceCable)
                Section {
                    if appModel.venues.isEmpty {
                        Text("No hackerspace or conference chat rooms loaded yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appModel.venues) { venue in
                            let category = SpaceCategory.classify(tags: venue.tags, name: venue.name)
                            let target = ChatRoomTarget.venue(
                                id: venue.id,
                                name: venue.name,
                                subtitle: category == .conferenceVenue ? "Conference Venue Room" : "Hackerspace Room",
                                discordLink: nil
                            )
                            NavigationLink(value: target) {
                                HStack(spacing: 12) {
                                    Image(systemName: category == .conferenceVenue ? "person.3.sequence.fill" : "cpu.fill")
                                        .font(.title3)
                                        .foregroundStyle(.tint)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(venue.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(venue.locale.name ?? venue.locale.label ?? "Live Room")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .accessibilityIdentifier("chat.row")
                        }
                    }
                } header: {
                    Text("Hackerspace & Conference Rooms")
                } footer: {
                    Text("Each hackerspace and conference venue hosts its own real-time AudienceKit chat room.")
                }

                // Regional Locale Chat Rooms
                if !appModel.locales.isEmpty {
                    Section("Regional Hacker Rooms") {
                        ForEach(appModel.locales) { locale in
                            let name = locale.name ?? locale.label ?? "Regional Chat"
                            let target = ChatRoomTarget.locale(id: locale.id, name: name)
                            NavigationLink(value: target) {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(.subheadline.weight(.semibold))
                                        if let cities = locale.cityNames, !cities.isEmpty {
                                            Text(cities.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                } icon: {
                                    Image(systemName: "globe.americas.fill")
                                        .foregroundStyle(.teal)
                                }
                            }
                            .accessibilityIdentifier("chat.row")
                        }
                    }
                }
            }
            .navigationTitle("Chat")
            .refreshable {
                await appModel.refreshCatalog()
            }
            .navigationDestination(for: ChatRoomTarget.self) { target in
                RoomChatScreen(room: target)
            }
            .alert("Join Con or Space Discord", isPresented: $showingDiscordPrompt) {
                TextField("Invite code or URL (e.g. defcon)", text: $customDiscordInvite)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {
                    customDiscordInvite = ""
                }
                Button("Open in Discord") {
                    openCustomDiscordInvite(customDiscordInvite)
                    customDiscordInvite = ""
                }
            } message: {
                Text("Enter a Discord invite code or URL for your conference or hackerspace.")
            }
        }
    }

    private func openCustomDiscordInvite(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let url = URL(string: trimmed), url.scheme != nil {
            openURL(url)
        } else if let url = URL(string: "https://discord.gg/\(trimmed)") {
            openURL(url)
        }
    }
}
