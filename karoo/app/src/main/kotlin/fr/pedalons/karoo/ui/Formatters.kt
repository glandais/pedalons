package fr.pedalons.karoo.ui

import android.content.Context
import android.text.format.DateFormat
import fr.pedalons.karoo.R
import io.hammerhead.karooext.models.UserProfile
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

// Conversion constants
private const val METERS_PER_MILE = 1609.344
private const val METERS_PER_FOOT = 0.3048
private const val METERS_PER_KM = 1000.0

/**
 * Formats a UTC instant as a short local date and time in the device's zone — on every screen, as
 * the Garmin app does and as the API contract describes for `startDateTime`.
 */
internal fun formatDateTime(context: Context, isoDateTime: String?): String? {
    if (isoDateTime.isNullOrBlank()) return null

    return try {
        val instant = Instant.parse(isoDateTime)
        val localDateTime = instant.atZone(ZoneId.systemDefault()).toLocalDateTime()

        val dateFormatter = DateTimeFormatter.ofLocalizedDate(FormatStyle.SHORT)
        val timeFormatter =
            if (DateFormat.is24HourFormat(context)) {
                DateTimeFormatter.ofPattern("HH:mm")
            } else {
                DateTimeFormatter.ofPattern("h:mm a")
            }

        "${localDateTime.format(dateFormatter)} ${localDateTime.format(timeFormatter)}"
    } catch (_: Exception) {
        null
    }
}

internal fun formatDistance(
    context: Context,
    distanceMeters: Float,
    userProfile: UserProfile?,
): String {
    val isImperial =
        userProfile?.preferredUnit?.distance == UserProfile.PreferredUnit.UnitType.IMPERIAL
    return if (isImperial) {
        val miles = distanceMeters / METERS_PER_MILE
        context.getString(R.string.distance_format_mi, miles)
    } else {
        val km = distanceMeters / METERS_PER_KM
        context.getString(R.string.distance_format_km, km)
    }
}

internal fun formatElevation(
    context: Context,
    elevationMeters: Float,
    userProfile: UserProfile?,
): String {
    val isImperial =
        userProfile?.preferredUnit?.elevation == UserProfile.PreferredUnit.UnitType.IMPERIAL
    return if (isImperial) {
        val feet = (elevationMeters / METERS_PER_FOOT).toInt()
        context.getString(R.string.elevation_format_ft, feet)
    } else {
        context.getString(R.string.elevation_format_m, elevationMeters.toInt())
    }
}
