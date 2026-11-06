package com.hackdifferent.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Identifies a live chat room on Action Cable: either a Venue (hackerspace / con venue) or a Locale.
 */
public sealed interface ChatRoomTarget {
    public val id: String
    public val recordId: String
    public val displayName: String
    public val subtitle: String?
    public val discordLink: DiscordChannelLink?
    public val subscriptionField: String
    public val argumentName: String

    public data class VenueRoom(
        override val recordId: String,
        override val displayName: String,
        override val subtitle: String? = null,
        override val discordLink: DiscordChannelLink? = null,
    ) : ChatRoomTarget {
        override val id: String = "venue:$recordId"
        override val subscriptionField: String = "venueChat"
        override val argumentName: String = "venueId"
    }

    public data class LocaleRoom(
        override val recordId: String,
        override val displayName: String,
    ) : ChatRoomTarget {
        override val id: String = "locale:$recordId"
        override val subtitle: String = "Regional Hacker Chat"
        override val discordLink: DiscordChannelLink? = null
        override val subscriptionField: String = "localeChat"
        override val argumentName: String = "localeId"
    }
}

/**
 * A message in a venue or conference chat room.
 */
@Serializable
public data class ChatMessageItem(
    val id: String,
    private val body: String? = null,
    private val message: String? = null,
    @SerialName("name") val senderName: String = "Hacker",
    val userId: String? = null,
    val avatarUrl: String? = null,
    val sentAt: String? = null,
    val role: String? = null,
    val kind: String? = null,
    val title: String? = null,
    val pinned: Boolean = false,
) {
    public val text: String
        get() = body ?: message.orEmpty()
}

/**
 * Someone currently present in a chat room.
 */
@Serializable
public data class ChatParticipant(
    val userId: String,
    val name: String = "Hacker",
    val avatarUrl: String? = null,
    val friend: Boolean = false,
) {
    public val id: String get() = userId
}
