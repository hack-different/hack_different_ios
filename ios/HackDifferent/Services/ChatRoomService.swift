//
//  ChatRoomService.swift
//  HackDifferent
//

import AudienceKit
import Foundation
import Observation

/// Manages a live `AudienceCable` subscription for a Hackerspace, Conference Venue, or Locale chat room.
@MainActor
@Observable
public final class ChatRoomViewModel {
    public enum ConnectionStatus: Equatable, Sendable {
        case connecting
        case connected
        case outOfRange
        case notPresent(String)
        case disconnected(reconnecting: Bool)
    }

    public let room: ChatRoomTarget
    public private(set) var status: ConnectionStatus = .connecting
    public private(set) var messages: [ChatMessageItem] = []
    public private(set) var pinnedMessage: ChatMessageItem?
    public private(set) var participants: [ChatParticipant] = []
    public private(set) var isSending = false
    public private(set) var sendError: String?

    private let cable: AudienceCable
    private let api: HackDifferentAPI
    private let client: AudienceKitClient
    @ObservationIgnored private var subscriptionTask: Task<Void, Never>?

    public init(room: ChatRoomTarget, cable: AudienceCable, api: HackDifferentAPI, client: AudienceKitClient) {
        self.room = room
        self.cable = cable
        self.api = api
        self.client = client
    }

    public func connect(watch: Bool = false) {
        subscriptionTask?.cancel()
        status = .connecting

        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            let audienceID = (try? await self.client.audienceID()) ?? AppConfiguration.defaultAudienceID
            let stream = await self.cable.subscribe(
                query: Self.subscriptionDocument(for: self.room, watch: watch),
                variables: ["id": .string(self.room.recordID.lowercased())],
                operationName: "ChatRoom",
                audienceID: audienceID
            )

            for await cableEvent in stream {
                guard !Task.isCancelled else { break }
                self.handle(cableEvent)
            }
        }
    }

    public func disconnect() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
    }

    public func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        isSending = true
        sendError = nil
        defer { isSending = false }

        do {
            let sent = try await api.sendChatMessage(trimmed, in: room)
            appendOrUpdateMessage(sent)
        } catch let error as AudienceKitError {
            sendError = error.message
        } catch {
            sendError = error.localizedDescription
        }
    }

    public func deleteOwnMessage(_ message: ChatMessageItem) async {
        do {
            try await api.removeMyChatMessage(id: message.id)
            messages.removeAll { $0.id == message.id }
        } catch let error as AudienceKitError {
            sendError = error.message
        } catch {
            sendError = error.localizedDescription
        }
    }

    private func handle(_ event: AudienceCable.Event) {
        switch event {
        case .subscribed:
            break
        case let .result(data):
            processPayload(data)
        case .rejected:
            status = .notPresent("Check in at \(room.displayName) or join the Discord server to chat from anywhere.")
        case let .disconnected(_, reconnects):
            status = .disconnected(reconnecting: reconnects)
        }
    }

    private func processPayload(_ data: Data) {
        guard let envelope = try? JSONDecoder.audienceKit.decode(RoomSubscriptionEnvelope.self, from: data) else {
            return
        }

        if let errors = envelope.errors, !errors.isEmpty, envelope.data?.room == nil {
            let summary = errors.compactMap(\.message).first
                ?? "Chat requires presence at \(room.displayName)."
            status = .notPresent(summary)
            return
        }

        guard let roomEvent = envelope.data?.room else { return }

        switch roomEvent.typename {
        case "ChatJoined":
            status = (roomEvent.outOfRange == true) ? .outOfRange : .connected
            participants = roomEvent.roster?.people ?? []
            messages = (roomEvent.history ?? []).compactMap(\.message)
            pinnedMessage = roomEvent.pinnedMessage?.message
        case "ChatMessagePosted":
            if let posted = roomEvent.message {
                appendOrUpdateMessage(posted)
            }
        case "ChatMessageUpdated":
            if let updated = roomEvent.message {
                appendOrUpdateMessage(updated)
            }
        case "ChatMessageRemoved":
            if let removedID = roomEvent.messageId {
                messages.removeAll { $0.id.caseInsensitiveCompare(removedID) == .orderedSame }
            }
        case "ChatPinChanged":
            if roomEvent.pinned == true {
                pinnedMessage = roomEvent.announcement
            } else {
                pinnedMessage = nil
            }
        case "ChatRoomCleared":
            messages.removeAll()
        case "ChatPresenceChanged":
            if let userId = roomEvent.userId {
                let presence = roomEvent.presence?.uppercased() ?? "OFFLINE"
                if presence == "ONLINE" {
                    let participant = ChatParticipant(
                        userId: userId,
                        name: roomEvent.name ?? "Hacker",
                        avatarUrl: roomEvent.avatarUrl
                    )
                    if !participants.contains(where: { $0.userId == userId }) {
                        participants.append(participant)
                    }
                } else {
                    participants.removeAll { $0.userId == userId }
                }
            }
        case "ChatRangeChanged":
            status = (roomEvent.outOfRange == true) ? .outOfRange : .connected
        case "ChatLeft":
            status = .notPresent("You left the \(room.displayName) chat range.")
        default:
            break
        }
    }

    private func appendOrUpdateMessage(_ item: ChatMessageItem) {
        if let index = messages.firstIndex(where: { $0.id.caseInsensitiveCompare(item.id) == .orderedSame }) {
            messages[index] = item
        } else {
            messages.append(item)
        }
    }

    static func subscriptionDocument(for room: ChatRoomTarget, watch: Bool) -> String {
        let watchArg = watch ? ", watch: true" : ""
        let fields = HackDifferentAPI.Documents.chatMessageFields
        return """
        subscription ChatRoom($id: ID!) {
          room: \(room.subscriptionField)(\(room.argumentName): $id\(watchArg)) {
            __typename
            ... on ChatJoined {
              outOfRange
              roster {
                people { userId name avatarUrl friend }
              }
              history { message { \(fields) } }
              pinnedMessage { message { \(fields) } }
            }
            ... on ChatMessagePosted {
              message { \(fields) }
            }
            ... on ChatMessageUpdated {
              message { \(fields) }
            }
            ... on ChatMessageRemoved {
              messageId
            }
            ... on ChatPinChanged {
              messageId
              pinned
              announcement { \(fields) }
            }
            ... on ChatRoomCleared {
              clearedAt
            }
            ... on ChatPresenceChanged {
              userId
              presence
              name
              avatarUrl
            }
            ... on ChatRangeChanged {
              outOfRange
            }
            ... on ChatLeft {
              reason
            }
          }
        }
        """
    }
}

private struct RoomSubscriptionEnvelope: Decodable, Sendable {
    struct DataContainer: Decodable, Sendable {
        var room: RoomEventWire?
    }
    struct ErrorItem: Decodable, Sendable {
        var message: String?
    }
    var data: DataContainer?
    var errors: [ErrorItem]?
}

private struct RoomEventWire: Decodable, Sendable {
    struct RosterWire: Decodable, Sendable {
        var people: [ChatParticipant]?
    }
    struct PostedWire: Decodable, Sendable {
        var message: ChatMessageItem?
    }

    var typename: String?
    var outOfRange: Bool?
    var roster: RosterWire?
    var history: [PostedWire]?
    var pinnedMessage: PostedWire?
    var message: ChatMessageItem?
    var announcement: ChatMessageItem?
    var messageId: String?
    var pinned: Bool?
    var userId: String?
    var presence: String?
    var name: String?
    var avatarUrl: String?
    var reason: String?

    enum CodingKeys: String, CodingKey {
        case typename = "__typename"
        case outOfRange, roster, history, pinnedMessage, message, announcement
        case messageId, pinned, userId, presence, name, avatarUrl, reason
    }
}
