package com.hackdifferent.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.audiencekit.AudienceKitSDK
import com.hackdifferent.app.HackDifferentAppState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(appState: HackDifferentAppState) {
    val context = LocalContext.current
    val user = appState.currentUser

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Profile & Community") })
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Card(
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = user?.name ?: listOfNotNull(user?.firstName, user?.lastName).joinToString(" ").ifBlank { "Hack Different Member" },
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    )
                    user?.emailAddress?.let { email ->
                        Text(
                            text = email,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (user?.isAdmin == true) {
                        Text(
                            text = "Audience Admin",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }

            Card(
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = "Community Links",
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                    )
                    OutlinedButton(
                        onClick = { appState.openExternalUrl(context, "https://hackdiffe.rent") },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Hack Different Website (hackdiffe.rent)")
                    }
                    OutlinedButton(
                        onClick = { appState.openExternalUrl(context, "https://discord.gg/nUZC4aCM9r") },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Hack Different Discord")
                    }
                    OutlinedButton(
                        onClick = { appState.openExternalUrl(context, "https://github.com/hack-different") },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("GitHub (github.com/hack-different)")
                    }
                }
            }

            Card(
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    InfoRow("Audience Host", appState.config.host)
                    InfoRow("Audience ID", appState.config.audienceId.take(8) + "…")
                    InfoRow("App Version", "${appState.config.versionName} (${appState.config.versionCode})")
                    InfoRow("AudienceKit SDK", AudienceKitSDK.VERSION)
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            OutlinedButton(
                onClick = { appState.signOut() },
                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
            ) {
                Text("Sign Out")
            }
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
        )
    }
}
