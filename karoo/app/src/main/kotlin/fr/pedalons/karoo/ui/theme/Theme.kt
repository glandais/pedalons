package fr.pedalons.karoo.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// Dark theme optimized for outdoor visibility on Karoo display
private val DarkColorScheme =
    darkColorScheme(
        primary = Color(0xFF748FFC), // Indigo-4 - brand primary, high contrast on black
        onPrimary = Color.Black,
        secondary = Color(0xFFFFA94D), // Orange-4 - brand accent
        onSecondary = Color.Black,
        background = Color.Black,
        onBackground = Color.White,
        surface = Color(0xFF1F1F1F), // Dark-8
        onSurface = Color.White,
        surfaceVariant = Color(0xFF2E2E2E), // Dark-6
        onSurfaceVariant = Color(0xFFB8B8B8), // Dark-1
        error = Color(0xFFFF6B6B), // Red-5
        onError = Color.White,
    )

// The business colour of a trip, teal (contracts/brand-colors.yaml: RIDE blue, TRIP teal), in its
// light shade for this dark theme. A ride takes the theme's primary.
val TripAccent = Color(0xFF3BC9DB) // Cyan-4

private val AppTypography =
    Typography(
        displayLarge =
            TextStyle(
                fontWeight = FontWeight.Bold,
                fontSize = 48.sp,
            ),
        displayMedium =
            TextStyle(
                fontWeight = FontWeight.Bold,
                fontSize = 36.sp,
            ),
        displaySmall =
            TextStyle(
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp,
            ),
        headlineMedium =
            TextStyle(
                fontWeight = FontWeight.SemiBold,
                fontSize = 24.sp,
            ),
        headlineSmall =
            TextStyle(
                fontWeight = FontWeight.SemiBold,
                fontSize = 20.sp,
            ),
        bodyLarge =
            TextStyle(
                fontWeight = FontWeight.Normal,
                fontSize = 18.sp,
            ),
        bodyMedium =
            TextStyle(
                fontWeight = FontWeight.Normal,
                fontSize = 16.sp,
            ),
        bodySmall =
            TextStyle(
                fontWeight = FontWeight.Normal,
                fontSize = 14.sp,
            ),
        labelLarge =
            TextStyle(
                fontWeight = FontWeight.Medium,
                fontSize = 16.sp,
            ),
    )

@Composable
fun PedalonsKarooTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography = AppTypography,
        content = content,
    )
}
