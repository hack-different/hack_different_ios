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

    /// The SDK's room for this target. IDs are sent lowercased, as the API stores them.
    public var room: ChatRoom {
        switch self {
        case let .venue(id, _, _, _): .venue(id: id.lowercased())
        case let .locale(id, _): .locale(id: id.lowercased())
        }
    }
}

extension ChatMessage {
    /// Who sent it, for display.
    public var senderName: String { name ?? "Hacker" }
}

extension ChatRosterPerson {
    /// Their name, for display.
    public var displayName: String { name ?? "Hacker" }
}
