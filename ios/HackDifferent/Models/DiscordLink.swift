//
//  DiscordLink.swift
//  HackDifferent
//

import Foundation

/// A social profile link returned on a venue or person's `profile.socialLinks`.
public struct SocialLink: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let handle: String
    public let provider: String
    public let url: URL?

    public init(id: String, handle: String, provider: String, url: URL? = nil) {
        self.id = id
        self.handle = handle
        self.provider = provider
        self.url = url
    }

    enum CodingKeys: String, CodingKey {
        case id, handle, provider, url
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        handle = try container.decodeIfPresent(String.self, forKey: .handle) ?? ""
        provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? ""
        if let rawURL = try container.decodeIfPresent(String.self, forKey: .url),
           !rawURL.isEmpty {
            url = URL(string: rawURL)
        } else {
            url = nil
        }
    }

    public var isDiscord: Bool {
        if provider.lowercased() == "discord" {
            return true
        }
        if let host = url?.host?.lowercased(),
           host.contains("discord.gg") || host.contains("discord.com") {
            return true
        }
        return false
    }

    public var systemImage: String {
        if isDiscord { return "bubble.left.and.bubble.right.fill" }
        switch provider.lowercased() {
        case "github": return "chevron.left.forwardslash.chevron.right"
        case "mastodon", "bluesky", "threads", "x", "twitter": return "at"
        case "youtube": return "play.rectangle.fill"
        case "instagram": return "camera.fill"
        default: return "link"
        }
    }

    public var displayLabel: String {
        if isDiscord {
            return handle.isEmpty ? "Discord Server" : "Discord (\(handle))"
        }
        return handle.isEmpty ? provider.capitalized : "@\(handle)"
    }
}

/// Represents a resolved Discord server or channel link for a hackerspace, conference venue, or event.
public struct DiscordChannelLink: Hashable, Sendable, Identifiable {
    public var id: String { webURL.absoluteString }
    public let title: String
    public let subtitle: String
    public let webURL: URL

    public init(title: String, subtitle: String, webURL: URL) {
        self.title = title
        self.subtitle = subtitle
        self.webURL = webURL
    }

    /// Extracts a Discord link from a list of `SocialLink`s or free-form description text.
    public static func resolve(
        title: String,
        socialLinks: [SocialLink] = [],
        description: String? = nil,
        sourceURL: URL? = nil
    ) -> DiscordChannelLink? {
        if let link = socialLinks.first(where: \.isDiscord) {
            if let url = link.url {
                return DiscordChannelLink(
                    title: title,
                    subtitle: link.handle.isEmpty ? "Join Discord" : link.handle,
                    webURL: url
                )
            } else if !link.handle.isEmpty,
                      let url = URL(string: "https://discord.gg/\(link.handle)") {
                return DiscordChannelLink(
                    title: title,
                    subtitle: "discord.gg/\(link.handle)",
                    webURL: url
                )
            }
        }

        if let sourceURL,
           let host = sourceURL.host?.lowercased(),
           host.contains("discord.gg") || host.contains("discord.com") {
            return DiscordChannelLink(
                title: title,
                subtitle: sourceURL.host ?? "Discord",
                webURL: sourceURL
            )
        }

        if let description,
           let extracted = extractDiscordURL(from: description) {
            return DiscordChannelLink(
                title: title,
                subtitle: extracted.host ?? "Discord",
                webURL: extracted
            )
        }

        return nil
    }

    public static func extractDiscordURL(from text: String) -> URL? {
        let pattern = #"https?://(?:www\.)?(?:discord\.gg|discord\.com/invite|discord\.com/channels)/[A-Za-z0-9_\-/]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let matchRange = Range(match.range, in: text) else {
            return nil
        }
        return URL(string: String(text[matchRange]))
    }
}
