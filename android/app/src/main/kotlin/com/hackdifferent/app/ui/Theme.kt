package com.hackdifferent.app.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.audiencekit.Branding

private val HackGreen = Color(0xFF32D74B)
private val HackCyan = Color(0xFF5AC8FA)
private val HackDarkBg = Color(0xFF0E110E)
private val HackDarkSurface = Color(0xFF181C18)

@Composable
fun HackDifferentTheme(
    branding: Branding? = null,
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val dynamicAccent = branding?.theme?.color("accent", dark = darkTheme)?.let { Color(it.toArgb()) }
    val primaryColor = dynamicAccent ?: HackGreen

    val colorScheme = if (darkTheme) {
        darkColorScheme(
            primary = primaryColor,
            secondary = HackCyan,
            background = HackDarkBg,
            surface = HackDarkSurface,
        )
    } else {
        lightColorScheme(
            primary = primaryColor,
            secondary = HackCyan,
        )
    }

    MaterialTheme(
        colorScheme = colorScheme,
        content = content,
    )
}
