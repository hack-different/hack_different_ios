//
//  ChatModels.swift
//  HackDifferent
//

import AudienceKit
import Foundation

/// Identifies a live chat room on AudienceCable: either a Venue (hackerspace / con venue) or a Locale.
public enum ChatRoomTarget: Hashable, Sendable, Identifiable {
    case venue(id: String, name: String, subtitle: String?, discordLink: DiscordChannelLink?)
    case locale(id: String, name: String)

    public var id: String {
        switch self {
        case let .venue(id, _, _, _): "venue:\(id)"
        case let .locale(id, _): "locale:\(id)"
        }
    }

    public var recordID: String {
        switch self {
        case let .venue(id, _, _, _), let .locale(id, _): id
        }
    }

    public var displayName: String {
        switch self {
        case let .venue(_, name, _, _), let .locale(_, name): name
        }
    }

    public var subtitle: String? {
        switch self {
        case let .venue(_, _, subtitle, _): subtitle
        case .locale: "Regional Hacker Chat"
        }
    }

    public var discordLink: DiscordChannelLink? {
        switch self {
        case let .venue(_, _, _, discord): discord
        case .locale: nil
        }
    }

    public var subscriptionField: String {
        switch self {
        case .venue: "venueChat"
        case .locale: "localeChat"
        }
    }

    public var argumentName: String {
        switch self {
        case .venue: "venueId"
        case .locale: "localeId"
        }
    }
}

/// A message in a venue or conference chat room.
public struct ChatMessageItem: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let body: String
    public let senderName: String
    public let userId: String?
    public let avatarUrl: String?
    public let sentAt: Date?
    public let role: String?
    public let kind: String?
    public let title: String?
    public let pinned: Bool

    public init(
        id: String,
        body: String,
        senderName: String,
        userId: String? = nil,
        avatarUrl: String? = nil,
        sentAt: Date? = nil,
        role: String? = nil,
        kind: String? = nil,
        title: String? = nil,
        pinned: Bool = false
    ) {
        self.id = id
        self.body = body
        self.senderName = senderName
        self.userId = userId
        self.avatarUrl = avatarUrl
        self.sentAt = sentAt
        self.role = role
        self.kind = kind
        self.title = title
        self.pinned = pinned
    }

    enum CodingKeys: String, CodingKey {
        case id, message, body, name, userId, avatarUrl, sentAt, role, kind, title, pinned
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let rawBody = try container.decodeIfPresent(String.self, forKey: .body)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? ""
        body = rawBody
        senderName = try container.decodeIfPresent(String.self, forKey: .name) ?? "Hacker"
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        if let sentText = try container.decodeIfPresent(String.self, forKey: .sentAt) {
            sentAt = ISO8601.date(from: sentText)
        } else {
            sentAt = nil
        }
        role = try container.decodeIfPresent(String.self, forKey: .role)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(body, forKey: .body)
        try container.encode(senderName, forKey: .name)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try container.encodeIfPresent(sentAt.map(ISO8601.string(from:)), forKey: .sentAt)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(pinned, forKey: .pinned)
    }
}

/// Someone currently present in a chat room.
public struct ChatParticipant: Codable, Hashable, Sendable, Identifiable {
    public var id: String { userId }
    public let userId: String
    public let name: String
    public let avatarUrl: String?
    public let friend: Bool

    public init(userId: String, name: String, avatarUrl: String? = nil, friend: Bool = false) {
        self.userId = userId
        self.name = name
        self.avatarUrl = avatarUrl
        self.friend = friend
    }

    enum CodingKeys: String, CodingKey {
        case userId, name, avatarUrl, friend
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Hacker"
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        friend = try container.decodeIfPresent(Bool.self, forKey: .friend) ?? false
    }
}
