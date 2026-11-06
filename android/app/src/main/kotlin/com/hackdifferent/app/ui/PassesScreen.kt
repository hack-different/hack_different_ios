package com.hackdifferent.app.ui

import android.graphics.Bitmap
import android.graphics.Color as AndroidColor
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.QrCode2
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.audiencekit.Admission
import com.audiencekit.CoverPass
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import com.hackdifferent.app.HackDifferentAppState
import com.hackdifferent.core.formattedAmount
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PassesScreen(appState: HackDifferentAppState) {
    var epochSeconds by remember { mutableLongStateOf(System.currentTimeMillis() / 1000) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        while (true) {
            epochSeconds = System.currentTimeMillis() / 1000
            delay(1_000L)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Passes & Admissions") },
                actions = {
                    IconButton(onClick = { appState.refreshAll() }) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh")
                    }
                },
            )
        },
    ) { innerPadding ->
        if (appState.admissions.isEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.QrCode2,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(56.dp),
                )
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = "No Active Passes Yet",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "Conference admissions and hackerspace passes you purchase will appear here with rotating offline QR codes.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                items(appState.admissions, key = { it.id }) { admission ->
                    AdmissionPassCard(
                        admission = admission,
                        epochSeconds = epochSeconds,
                        onRefund = {
                            scope.launch {
                                runCatching { appState.api.refundAdmission(admission.id) }
                                appState.refreshAll()
                            }
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun AdmissionPassCard(
    admission: Admission,
    epochSeconds: Long,
    onRefund: () -> Unit,
) {
    val qrPayload = remember(admission.id, admission.passSecret, CoverPass.window(epochSeconds)) {
        admission.passCode(epochSeconds)
    }
    val qrBitmap = remember(qrPayload) {
        qrPayload?.let { generateQrBitmap(it, 512) }
    }
    val secondsRemaining = CoverPass.secondsUntilNextWindow(epochSeconds)

    Card(
        shape = RoundedCornerShape(18.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column {
                    Text(
                        text = admission.venue?.name ?: admission.event?.name ?: "Hack Different Pass",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    )
                    Text(
                        text = "Night: ${admission.night} • ${admission.status.name}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(
                    text = admission.total.formattedAmount,
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = MaterialTheme.colorScheme.primary,
                )
            }

            if (qrBitmap != null && qrPayload != null) {
                Image(
                    bitmap = qrBitmap.asImageBitmap(),
                    contentDescription = "Rotating Pass QR Code",
                    modifier = Modifier.size(220.dp),
                )
                LinearProgressIndicator(
                    progress = { secondsRemaining.toFloat() / CoverPass.WINDOW_SECONDS.toFloat() },
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    text = "Rotates in ${secondsRemaining}s • $qrPayload",
                    style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            if (admission.isRefundable) {
                OutlinedButton(onClick = onRefund, modifier = Modifier.fillMaxWidth()) {
                    Text("Refund Pass")
                }
            }
        }
    }
}

private fun generateQrBitmap(content: String, sizePx: Int): Bitmap? = runCatching {
    val matrix = QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, sizePx, sizePx)
    val pixels = IntArray(sizePx * sizePx)
    for (y in 0 until sizePx) {
        val offset = y * sizePx
        for (x in 0 until sizePx) {
            pixels[offset + x] = if (matrix.get(x, y)) AndroidColor.BLACK else AndroidColor.WHITE
        }
    }
    Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888).apply {
        setPixels(pixels, 0, sizePx, 0, 0, sizePx, sizePx)
    }
}.getOrNull()
