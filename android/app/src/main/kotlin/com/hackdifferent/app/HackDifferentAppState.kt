package com.hackdifferent.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.audiencekit.Admission
import com.audiencekit.AppleWebSignIn
import com.audiencekit.AudienceKitClient
import com.audiencekit.AudienceKitEnvironment
import com.audiencekit.AudienceKitException
import com.audiencekit.AudienceLocale
import com.audiencekit.Branding
import com.audiencekit.CableConnection
import com.audiencekit.CableSocket
import com.audiencekit.CableSocketFactory
import com.audiencekit.DeviceDescription
import com.audiencekit.RSVPState
import com.audiencekit.SelfUser
import com.audiencekit.SessionEvent
import com.audiencekit.Venue
import com.audiencekit.android.KeystoreTokenStore
import com.audiencekit.android.current
import com.hackdifferent.core.AppConfig
import com.hackdifferent.core.ChatRoomTarget
import com.hackdifferent.core.ConferenceEvent
import com.hackdifferent.core.HackDifferentApi
import com.hackdifferent.core.VenueDetail
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener

enum class AuthState {
    RESTORING,
    SIGNED_OUT,
    SIGNING_IN,
    SIGNED_IN,
}

enum class AppTab(val label: String) {
    EVENTS("Events"),
    SPACES("Spaces"),
    PASSES("Passes"),
    CHAT("Chat"),
    PROFILE("Profile"),
}

class HackDifferentAppState(
    context: Context,
    val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
    private val appContext = context.applicationContext
    private val applePrefs = appContext.getSharedPreferences("com.hackdifferent.app.apple_signin", Context.MODE_PRIVATE)
    private val okHttpClient = OkHttpClient()

    val config = AppConfig(
        baseUrl = BuildConfig.API_BASE_URL,
        host = BuildConfig.AUDIENCE_HOST,
        audienceId = BuildConfig.AUDIENCE_ID,
        facebookAppId = BuildConfig.FACEBOOK_APP_ID,
        appleServicesId = BuildConfig.APPLE_SERVICES_ID,
        environment = if (BuildConfig.AUDIENCEKIT_ENVIRONMENT == "staging") {
            AudienceKitEnvironment.STAGING
        } else {
            AudienceKitEnvironment.PRODUCTION
        },
        versionName = BuildConfig.VERSION_NAME,
        versionCode = BuildConfig.VERSION_CODE.toString(),
    )

    val client = AudienceKitClient(
        configuration = config.audienceKitConfiguration,
        tokenStore = KeystoreTokenStore(
            context = appContext,
            preferencesName = "com.hackdifferent.app.session",
            keyAlias = "com.hackdifferent.app.session",
        ),
    )

    val api = HackDifferentApi(client = client, config = config)

    val cable: CableConnection = CableConnection(
        configuration = config.audienceKitConfiguration,
        token = { client.sessionToken() },
        socketFactory = okHttpSocketFactory(okHttpClient),
    ).also { connection ->
        connection.onUnauthorized = { token ->
            client.sessionRejected(token)
        }
    }

    var authState by mutableStateOf(AuthState.RESTORING)
        private set
    var currentUser by mutableStateOf<SelfUser?>(null)
        private set
    var branding by mutableStateOf<Branding?>(null)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var sessionEndedBanner by mutableStateOf<String?>(null)
        private set
    var isReviewSignInAvailable by mutableStateOf(false)
        private set

    var selectedTab by mutableStateOf(AppTab.EVENTS)
    var activeChatRoom by mutableStateOf<ChatRoomTarget?>(null)

    var venues by mutableStateOf<List<Venue>>(emptyList())
        private set
    var locales by mutableStateOf<List<AudienceLocale>>(emptyList())
        private set
    var events by mutableStateOf<List<ConferenceEvent>>(emptyList())
        private set
    var admissions by mutableStateOf<List<Admission>>(emptyList())
        private set
    var isLoadingDirectory by mutableStateOf(false)
        private set

    val audienceName: String
        get() = branding?.audience?.name ?: "Hack Different"

    val tagline: String
        get() = branding?.theme?.tagline ?: "Hackerspaces, Conferences & Community"

    init {
        scope.launch {
            client.sessionEvents.collect { event ->
                when (event) {
                    SessionEvent.SIGNED_IN -> {
                        sessionEndedBanner = null
                        authState = AuthState.SIGNED_IN
                        refreshAll()
                    }
                    SessionEvent.SIGNED_OUT -> {
                        cable.disconnect()
                        currentUser = null
                        authState = AuthState.SIGNED_OUT
                    }
                    SessionEvent.SESSION_ENDED -> {
                        cable.disconnect()
                        currentUser = null
                        sessionEndedBanner = "Your session ended. Please sign in again."
                        authState = AuthState.SIGNED_OUT
                    }
                }
            }
        }
    }

    fun start() {
        scope.launch {
            launch {
                runCatching { client.branding() }.onSuccess { branding = it }
            }
            launch {
                isReviewSignInAvailable = api.isReviewSignInEnabled()
            }
            restoreSession()
        }
    }

    suspend fun restoreSession() {
        if (!client.isSignedIn) {
            authState = AuthState.SIGNED_OUT
            return
        }
        try {
            currentUser = client.me()
            authState = AuthState.SIGNED_IN
            errorMessage = null
            refreshAll()
        } catch (_: AudienceKitException.Unauthorized) {
            currentUser = null
            authState = AuthState.SIGNED_OUT
            sessionEndedBanner = "Your session expired. Please sign in again."
        } catch (_: Exception) {
            authState = AuthState.SIGNED_IN
            refreshAll()
        }
    }

    fun refreshAll() {
        scope.launch {
            isLoadingDirectory = true
            val venuesJob = launch {
                runCatching { api.venues() }.onSuccess { venues = it }
            }
            val localesJob = launch {
                runCatching { api.locales() }.onSuccess { locales = it }
            }
            val eventsJob = launch {
                runCatching { api.upcomingEvents() }.onSuccess { events = it }
            }
            val admissionsJob = launch {
                runCatching { api.admissions() }.onSuccess { admissions = it }
            }
            val meJob = launch {
                runCatching { client.me() }.onSuccess { if (it != null) currentUser = it }
            }
            venuesJob.join()
            localesJob.join()
            eventsJob.join()
            admissionsJob.join()
            meJob.join()
            isLoadingDirectory = false
        }
    }

    fun startAppleSignIn(activityContext: Context) {
        errorMessage = null
        sessionEndedBanner = null
        val signIn = AppleWebSignIn(
            servicesId = config.appleServicesId,
            redirectUri = AppleWebSignIn.callbackUrl(config.baseUrl),
            packageName = appContext.packageName,
        )
        applePrefs.edit()
            .putString("state", signIn.state)
            .putString("nonce", signIn.nonce)
            .apply()

        val customTabs = CustomTabsIntent.Builder().build()
        customTabs.launchUrl(activityContext, Uri.parse(signIn.authorizationUrl()))
    }

    fun handleIncomingIntent(intent: Intent?) {
        val url = intent?.data?.toString() ?: return
        if (!AppleWebSignIn.isCallbackUrl(url)) return

        val savedState = applePrefs.getString("state", null)
        val savedNonce = applePrefs.getString("nonce", null)
        if (savedState == null || savedNonce == null) {
            errorMessage = "Sign in with Apple session expired. Please try again."
            return
        }

        val signIn = AppleWebSignIn(
            servicesId = config.appleServicesId,
            redirectUri = AppleWebSignIn.callbackUrl(config.baseUrl),
            packageName = appContext.packageName,
            state = savedState,
            nonce = savedNonce,
        )

        when (val result = signIn.result(url)) {
            is AppleWebSignIn.Result.Credential -> {
                authState = AuthState.SIGNING_IN
                scope.launch {
                    try {
                        val device = DeviceDescription.current(appContext)
                        client.signInWithApple(result, signIn, device)
                        currentUser = runCatching { client.me() }.getOrNull()
                        authState = AuthState.SIGNED_IN
                    } catch (e: AudienceKitException) {
                        errorMessage = e.message ?: "Apple sign-in failed."
                        authState = AuthState.SIGNED_OUT
                    } catch (e: Exception) {
                        errorMessage = e.localizedMessage ?: "Apple sign-in failed."
                        authState = AuthState.SIGNED_OUT
                    }
                }
            }
            AppleWebSignIn.Result.Cancelled -> {
                authState = AuthState.SIGNED_OUT
            }
            is AppleWebSignIn.Result.Failed -> {
                errorMessage = result.reason
                authState = AuthState.SIGNED_OUT
            }
        }
    }

    fun signInWithReviewCode(code: String) {
        val trimmed = code.trim()
        if (trimmed.isEmpty()) return
        errorMessage = null
        sessionEndedBanner = null
        authState = AuthState.SIGNING_IN

        scope.launch {
            try {
                val device = DeviceDescription.current(appContext)
                api.signInWithReviewCode(trimmed, device)
                currentUser = runCatching { client.me() }.getOrNull()
                authState = AuthState.SIGNED_IN
            } catch (e: AudienceKitException) {
                errorMessage = e.message ?: "Review code sign-in failed."
                authState = AuthState.SIGNED_OUT
            } catch (e: Exception) {
                errorMessage = e.localizedMessage ?: "Review code sign-in failed."
                authState = AuthState.SIGNED_OUT
            }
        }
    }

    fun updateEventRsvp(eventId: String, state: RSVPState, onComplete: (RSVPState?) -> Unit = {}) {
        scope.launch {
            val updated = runCatching { api.setRsvp(state, eventId) }.getOrNull()
            if (updated != null) {
                events = events.map { evt ->
                    if (evt.id == eventId) evt.copy(rsvpState = updated) else evt
                }
            }
            onComplete(updated)
        }
    }

    suspend fun loadVenueDetail(venueId: String): VenueDetail? =
        runCatching { api.venueDetail(venueId) }.getOrNull()

    fun openChatRoom(room: ChatRoomTarget) {
        activeChatRoom = room
        selectedTab = AppTab.CHAT
    }

    fun signOut() {
        client.signOut()
    }

    fun openExternalUrl(context: Context, url: String) {
        runCatching {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }
    }

    private fun okHttpSocketFactory(httpClient: OkHttpClient): CableSocketFactory =
        CableSocketFactory { url, headers, listener ->
            val requestBuilder = Request.Builder().url(url)
            headers.forEach { (k, v) -> requestBuilder.header(k, v) }
            val webSocket = httpClient.newWebSocket(
                requestBuilder.build(),
                object : WebSocketListener() {
                    override fun onMessage(webSocket: WebSocket, text: String) {
                        listener.onMessage(text)
                    }

                    override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                        listener.onClosed(reason.ifBlank { null })
                    }

                    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                        listener.onFailure(t.message)
                    }
                },
            )
            object : CableSocket {
                override fun send(text: String): Boolean = webSocket.send(text)
                override fun close(code: Int, reason: String?) {
                    webSocket.close(code, reason)
                }
            }
        }
}
