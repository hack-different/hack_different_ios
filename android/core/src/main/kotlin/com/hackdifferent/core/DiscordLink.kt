package com.hackdifferent.core

import kotlinx.serialization.Serializable
import java.net.URI

/**
 * A social profile link returned on a venue or person's `profile.socialLinks`.
 */
@Serializable
public data class SocialLink(
    val id: String,
    val handle: String = "",
    val provider: String = "",
    val url: String? = null,
) {
    public val isDiscord: Boolean
        get() {
            if (provider.equals("discord", ignoreCase = true)) return true
            val host = url?.let { runCatching { URI(it).host?.lowercase() }.getOrNull() }.orEmpty()
            return host.contains("discord.gg") || host.contains("discord.com")
        }

    public val displayLabel: String
        get() {
            if (isDiscord) {
                return if (handle.isBlank()) "Discord Server" else "Discord ($handle)"
            }
            return if (handle.isBlank()) provider.replaceFirstChar { it.uppercase() } else "@$handle"
        }
}

/**
 * Represents a resolved Discord server or channel link for a hackerspace, conference venue, or event.
 */
public data class DiscordChannelLink(
    val title: String,
    val subtitle: String,
    val webUrl: String,
) {
    public val id: String get() = webUrl

    public companion object {
        private val DISCORD_URL_REGEX =
            Regex("""https?://(?:www\.)?(?:discord\.gg|discord\.com/invite|discord\.com/channels)/[A-Za-z0-9_\-/]+""", RegexOption.IGNORE_CASE)

        public fun resolve(
            title: String,
            socialLinks: List<SocialLink> = emptyList(),
            description: String? = null,
            sourceUrl: String? = null,
        ): DiscordChannelLink? {
            socialLinks.firstOrNull { it.isDiscord }?.let { link ->
                if (!link.url.isNullOrBlank()) {
                    return DiscordChannelLink(
                        title = title,
                        subtitle = link.handle.ifBlank { "Join Discord" },
                        webUrl = link.url,
                    )
                } else if (link.handle.isNotBlank()) {
                    return DiscordChannelLink(
                        title = title,
                        subtitle = "discord.gg/${link.handle}",
                        webUrl = "https://discord.gg/${link.handle}",
                    )
                }
            }

            if (!sourceUrl.isNullOrBlank()) {
                val host = runCatching { URI(sourceUrl).host?.lowercase() }.getOrNull().orEmpty()
                if (host.contains("discord.gg") || host.contains("discord.com")) {
                    return DiscordChannelLink(
                        title = title,
                        subtitle = host.ifBlank { "Discord" },
                        webUrl = sourceUrl,
                    )
                }
            }

            if (!description.isNullOrBlank()) {
                extractDiscordUrl(description)?.let { extracted ->
                    val host = runCatching { URI(extracted).host }.getOrNull() ?: "Discord"
                    return DiscordChannelLink(
                        title = title,
                        subtitle = host,
                        webUrl = extracted,
                    )
                }
            }

            return null
        }

        public fun extractDiscordUrl(text: String): String? =
            DISCORD_URL_REGEX.find(text)?.value
    }
}
