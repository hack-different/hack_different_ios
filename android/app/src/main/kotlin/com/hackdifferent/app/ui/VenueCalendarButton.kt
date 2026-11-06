package com.hackdifferent.app.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.audiencekit.AudienceKitClient
import com.audiencekit.CalendarFeed
import com.audiencekit.android.addToGoogleCalendar
import com.audiencekit.android.copyCalendarLink
import com.audiencekit.android.subscribeToCalendar
import com.audiencekit.calendarFeed
import com.audiencekit.followVenueInCalendar
import kotlinx.coroutines.launch

/**
 * "Add to calendar" on a venue: follows it in the person's one AudienceKit calendar feed, so every event there (a
 * hackerspace's meetups) shows up in their calendar and keeps up with changes, then offers to subscribe to the feed
 * for anyone who hasn't yet. Tapping it again offers to remove the venue.
 */
@Composable
internal fun VenueCalendarButton(client: AudienceKitClient, venueId: String, venueName: String) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var feed by remember { mutableStateOf<CalendarFeed?>(null) }
    var working by remember { mutableStateOf(false) }
    var offeringSubscribe by remember { mutableStateOf(false) }
    var confirmingRemove by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val following = feed?.follows(venueId) == true

    LaunchedEffect(venueId) { feed = runCatching { client.calendarFeed() }.getOrNull() }

    fun follow(on: Boolean) {
        working = true
        scope.launch {
            runCatching { client.followVenueInCalendar(venueId, following = on) }
                .onSuccess {
                    feed = it
                    if (on) offeringSubscribe = true
                }
                .onFailure { error = it.message ?: "Couldn't update your calendar." }
            working = false
        }
    }

    Column {
        OutlinedButton(
            onClick = { if (following) confirmingRemove = true else follow(true) },
            enabled = !working,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(Icons.Default.DateRange, contentDescription = null)
            Spacer(modifier = Modifier.padding(4.dp))
            Text(if (following) "In your calendar" else "Add to calendar")
        }
        error?.let {
            Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
        }
    }

    val links = feed?.links
    if (offeringSubscribe && links != null) {
        AlertDialog(
            onDismissRequest = { offeringSubscribe = false },
            title = { Text("$venueName's events are in your calendar feed") },
            text = {
                Text(
                    "If you already subscribed to your calendar feed, they show up on their own. Otherwise, " +
                        "subscribe once.",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    offeringSubscribe = false
                    if (!context.subscribeToCalendar(links)) context.copyCalendarLink(links)
                }) { Text("Subscribe") }
            },
            dismissButton = {
                Column {
                    TextButton(onClick = {
                        offeringSubscribe = false
                        context.addToGoogleCalendar(links)
                    }) { Text("Google Calendar") }
                    TextButton(onClick = {
                        offeringSubscribe = false
                        context.copyCalendarLink(links)
                    }) { Text("Copy link") }
                    TextButton(onClick = { offeringSubscribe = false }) { Text("Already subscribed") }
                }
            },
        )
    }

    if (confirmingRemove) {
        AlertDialog(
            onDismissRequest = { confirmingRemove = false },
            title = { Text("Remove $venueName from your calendar?") },
            text = { Text("Its events leave your calendar feed the next time your calendar checks it.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmingRemove = false
                    follow(false)
                }) { Text("Remove") }
            },
            dismissButton = { TextButton(onClick = { confirmingRemove = false }) { Text("Keep") } },
        )
    }
}
