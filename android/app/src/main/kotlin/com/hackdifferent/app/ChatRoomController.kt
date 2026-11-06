package com.hackdifferent.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.audiencekit.AudienceKitClient
import com.audiencekit.AudienceKitException
import com.audiencekit.CableConnection
import com.audiencekit.CableEvent
import com.hackdifferent.core.AppConfig
import com.hackdifferent.core.ChatMessageItem
import com.hackdifferent.core.ChatParticipant
import com.hackdifferent.core.ChatRoomTarget
import com.hackdifferent.core.HackDifferentApi
import com.hackdifferent.core.RoomSubscriptionData
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

sealed interface ChatConnectionStatus {
    data object Connecting : ChatConnectionStatus
    data object Connected : ChatConnectionStatus
    data object OutOfRange : ChatConnectionStatus
    data class NotPresent(val message: String) : ChatConnectionStatus
    data class Disconnected(val reconnecting: Boolean) : ChatConnectionStatus
}

class ChatRoomController(
    val room: ChatRoomTarget,
    private val cable: CableConnection,
    private val api: HackDifferentApi,
    private val client: AudienceKitClient,
    private val scope: CoroutineScope,
) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        coerceInputValues = true
    }

    var status by mutableStateOf<ChatConnectionStatus>(ChatConnectionStatus.Connecting)
        private set
    var messages by mutableStateOf<List<ChatMessageItem>>(emptyList())
        private set
    var pinnedMessage by mutableStateOf<ChatMessageItem?>(null)
        private set
    var participants by mutableStateOf<List<ChatParticipant>>(emptyList())
        private set
    var isSending by mutableStateOf(false)
        private set
    var sendError by mutableStateOf<String?>(null)
        private set

    private var subscriptionJob: Job? = null

    fun connect(watch: Boolean = false) {
        subscriptionJob?.cancel()
        status = ChatConnectionStatus.Connecting

        subscriptionJob = scope.launch {
            val audienceId = runCatching { client.audienceId() }.getOrDefault(AppConfig.DEFAULT_AUDIENCE_ID)
            val query = HackDifferentApi.Documents.chatRoomSubscription(room, watch)
            val variables = JsonObject(mapOf("id" to JsonPrimitive(room.recordId.lowercase())))

            cable.subscribe(
                audienceId = audienceId,
                query = query,
                variables = variables,
                operationName = "ChatRoom",
            ).collect { event ->
                handleCableEvent(event)
            }
        }
    }

    fun disconnect() {
        subscriptionJob?.cancel()
        subscriptionJob = null
    }

    fun sendMessage(text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty() || isSending) return
        isSending = true
        sendError = null

        scope.launch {
            try {
                val sent = api.sendChatMessage(trimmed, room)
                appendOrUpdateMessage(sent)
            } catch (e: AudienceKitException) {
                sendError = e.message ?: "Failed to send message."
            } catch (e: Exception) {
                sendError = e.localizedMessage ?: "Failed to send message."
            } finally {
                isSending = false
            }
        }
    }

    fun deleteOwnMessage(message: ChatMessageItem) {
        scope.launch {
            try {
                api.removeMyChatMessage(message.id)
                messages = messages.filterNot { it.id.equals(message.id, ignoreCase = true) }
            } catch (e: AudienceKitException) {
                sendError = e.message
            } catch (e: Exception) {
                sendError = e.localizedMessage
            }
        }
    }

    private fun handleCableEvent(event: CableEvent) {
        when (event) {
            CableEvent.Subscribed -> Unit
            is CableEvent.Result -> processResult(event)
            CableEvent.Rejected -> {
                status = ChatConnectionStatus.NotPresent(
                    "Check in at ${room.displayName} or join the Discord server to chat from anywhere.",
                )
            }
            is CableEvent.Disconnected -> {
                status = ChatConnectionStatus.Disconnected(reconnecting = event.reconnects)
            }
        }
    }

    private fun processResult(event: CableEvent.Result) {
        val envelope = event.result
        if (envelope.errors.isNotEmpty() && envelope.data == null) {
            val firstError = (envelope.errors.firstOrNull() as? JsonObject)
                ?.get("message")
                ?.let { (it as? JsonPrimitive)?.contentOrNull }
                ?: "Chat requires presence at ${room.displayName}."
            status = ChatConnectionStatus.NotPresent(firstError)
            return
        }

        val dataObj = envelope.data ?: return
        val parsed = runCatching {
            json.decodeFromJsonElement(RoomSubscriptionData.serializer(), dataObj)
        }.getOrNull() ?: return

        val roomEvent = parsed.room ?: return
        when (roomEvent.typename) {
            "ChatJoined" -> {
                status = if (roomEvent.outOfRange == true) {
                    ChatConnectionStatus.OutOfRange
                } else {
                    ChatConnectionStatus.Connected
                }
                participants = roomEvent.roster?.people.orEmpty()
                messages = roomEvent.history.orEmpty().mapNotNull { it.message }
                pinnedMessage = roomEvent.pinnedMessage?.message
            }
            "ChatMessagePosted", "ChatMessageUpdated" -> {
                roomEvent.message?.let(::appendOrUpdateMessage)
            }
            "ChatMessageRemoved" -> {
                val removedId = roomEvent.messageId ?: return
                messages = messages.filterNot { it.id.equals(removedId, ignoreCase = true) }
            }
            "ChatPinChanged" -> {
                pinnedMessage = if (roomEvent.pinned == true) roomEvent.announcement else null
            }
            "ChatRoomCleared" -> {
                messages = emptyList()
            }
            "ChatPresenceChanged" -> {
                val userId = roomEvent.userId ?: return
                val isOnline = roomEvent.presence?.equals("ONLINE", ignoreCase = true) == true
                if (isOnline) {
                    if (participants.none { it.userId == userId }) {
                        participants = participants + ChatParticipant(
                            userId = userId,
                            name = roomEvent.name ?: "Hacker",
                            avatarUrl = roomEvent.avatarUrl,
                        )
                    }
                } else {
                    participants = participants.filterNot { it.userId == userId }
                }
            }
            "ChatRangeChanged" -> {
                status = if (roomEvent.outOfRange == true) {
                    ChatConnectionStatus.OutOfRange
                } else {
                    ChatConnectionStatus.Connected
                }
            }
            "ChatLeft" -> {
                status = ChatConnectionStatus.NotPresent("You left the ${room.displayName} chat range.")
            }
        }
    }

    private fun appendOrUpdateMessage(item: ChatMessageItem) {
        val index = messages.indexOfFirst { it.id.equals(item.id, ignoreCase = true) }
        messages = if (index >= 0) {
            messages.toMutableList().also { it[index] = item }
        } else {
            messages + item
        }
    }
}
