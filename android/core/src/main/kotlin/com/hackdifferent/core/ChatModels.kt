package com.hackdifferent.core

import com.audiencekit.ChatMessage
import com.audiencekit.ChatRoom
import com.audiencekit.ChatRosterPerson

/**
 * Identifies a live chat room on Action Cable: either a Venue (hackerspace / con venue) or a Locale.
 */
public sealed interface ChatRoomTarget {
    public val id: String
    public val recordId: String
    public val displayName: String
    public val subtitle: String?
    public val discordLink: DiscordChannelLink?

    /** The SDK's room for this target. IDs are sent lowercased, as the API stores them. */
    public val room: ChatRoom

    public data class VenueRoom(
        override val recordId: String,
        override val displayName: String,
        override val subtitle: String? = null,
        override val discordLink: DiscordChannelLink? = null,
    ) : ChatRoomTarget {
        override val id: String = "venue:$recordId"
        override val room: ChatRoom get() = ChatRoom.Venue(recordId.lowercase())
    }

    public data class LocaleRoom(
        override val recordId: String,
        override val displayName: String,
    ) : ChatRoomTarget {
        override val id: String = "locale:$recordId"
        override val subtitle: String = "Regional Hacker Chat"
        override val discordLink: DiscordChannelLink? = null
        override val room: ChatRoom get() = ChatRoom.Locale(recordId.lowercase())
    }
}

/** Who sent it, for display. */
public val ChatMessage.senderName: String get() = name ?: "Hacker"

/** What it says, for display. */
public val ChatMessage.text: String get() = body.ifBlank { message }

/** Their name, for display. */
public val ChatRosterPerson.displayName: String get() = name ?: "Hacker"
