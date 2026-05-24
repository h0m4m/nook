package com.nook.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val NookColorScheme = lightColorScheme(
    primary = NookColors.Primary,
    onPrimary = NookColors.PrimaryForeground,
    secondary = NookColors.Secondary,
    onSecondary = NookColors.SecondaryForeground,
    tertiary = NookColors.Accent,
    background = NookColors.Background,
    onBackground = NookColors.Foreground,
    surface = NookColors.Card,
    onSurface = NookColors.CardForeground,
    surfaceVariant = NookColors.Input,
    onSurfaceVariant = NookColors.MutedForeground,
    outline = NookColors.Border,
)

@Composable
fun NookTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = NookColorScheme,
        typography = NookTypography,
        shapes = NookShapes,
        content = content,
    )
}
