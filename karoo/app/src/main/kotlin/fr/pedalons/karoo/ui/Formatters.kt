package fr.pedalons.karoo.ui

import android.content.Context
import fr.pedalons.karoo.R
import io.hammerhead.karooext.models.UserProfile
import java.text.NumberFormat
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.math.roundToInt

/*
 * The formats of the app and of the site, on the Karoo (docs/LEDGER_*.md API-191): the written
 * rules are docs/BRANDING.md §8.3 and the cards' KIT §8-9, the shared cases
 * `contracts/format-cases.json`, read here by `FormatCasesTest` as by the tests of the other two.
 * A format changed here alone makes the three diverge silently.
 */

// Conversion constants
private const val METERS_PER_MILE = 1609.344
private const val METERS_PER_FOOT = 0.3048
private const val METERS_PER_KM = 1000.0

// Between a value and its unit, and the French thousands separator: the plain no-break space,
// never the narrow one (BRANDING §8.3).
private const val NBSP = ' '
private const val NARROW_NBSP = ' '

/**
 * « Now », for « Aujourd'hui », « Demain » and « this year ». A test seam: the tests and the
 * screenshot goldens freeze it, production never touches it.
 */
internal object FormatClock {
    @Volatile var now: () -> Instant = Instant::now
}

/**
 * The language the texts are written in — French when the Karoo is in French, English otherwise, as
 * the string resources — so that a number or a date never follows another language than the words
 * around it.
 */
internal fun formatLocale(context: Context): Locale =
    if (context.resources.configuration.locales[0].language == "fr") Locale.FRENCH
    else Locale.ENGLISH

private fun isFrench(locale: Locale) = locale.language == "fr"

// === Numbers ===

private fun grouped(value: Int, locale: Locale): String =
    NumberFormat.getIntegerInstance(locale).format(value.toLong()).replace(NARROW_NBSP, NBSP)

/** « 92,4 km », « 28.8 mi »: one decimal, a no-break space before the unit. */
internal fun formatDistance(locale: Locale, distanceMeters: Float, imperial: Boolean): String {
    val value = distanceMeters / (if (imperial) METERS_PER_MILE else METERS_PER_KM)
    return String.format(locale, "%.1f", value) + NBSP + (if (imperial) "mi" else "km")
}

/** « 1 240 m », « 4,068 ft »: rounded, thousands grouped, a no-break space before the unit. */
internal fun formatElevation(locale: Locale, elevationMeters: Float, imperial: Boolean): String {
    val value = if (imperial) elevationMeters / METERS_PER_FOOT else elevationMeters.toDouble()
    return grouped(value.roundToInt(), locale) + NBSP + (if (imperial) "ft" else "m")
}

internal fun formatDistance(
    context: Context,
    distanceMeters: Float,
    userProfile: UserProfile?,
): String =
    formatDistance(
        formatLocale(context),
        distanceMeters,
        userProfile?.preferredUnit?.distance == UserProfile.PreferredUnit.UnitType.IMPERIAL,
    )

/** The elevation gain of a route: « 1 240 m D+ ». */
internal fun formatElevationGain(
    context: Context,
    elevationMeters: Float,
    userProfile: UserProfile?,
): String =
    context.getString(
        R.string.elevation_gain,
        formatElevation(
            formatLocale(context),
            elevationMeters,
            userProfile?.preferredUnit?.elevation == UserProfile.PreferredUnit.UnitType.IMPERIAL,
        ),
    )

// === Dates ===

private fun parseInstant(isoDateTime: String?): Instant? =
    if (isoDateTime.isNullOrBlank()) null
    else runCatching { Instant.parse(isoDateTime) }.getOrNull()

/**
 * The zone a departure is read in: the ride's own ([zone], an IANA name of the contract), the
 * Karoo's when the server sent none (older backend) or one this device does not know.
 */
private fun zoneOrDevice(zone: String?): ZoneId =
    zone?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: ZoneId.systemDefault()

/** 24 h in French (« 09:00 »), 12 h in English (« 9:00 AM »): the language decides. */
private fun formatTime(wall: ZonedDateTime, locale: Locale): String =
    wall.format(
        DateTimeFormatter.ofPattern(
            if (isFrench(locale)) "HH:mm" else "h:mm${NARROW_NBSP}a",
            locale,
        ),
    )

/** « sam. 12 avr. », « Sat, Apr 12 »; with the year when it is not [reference]'s. */
private fun formatDay(wall: ZonedDateTime, reference: ZonedDateTime, locale: Locale): String {
    val sameYear = wall.year == reference.year
    val pattern =
        if (isFrench(locale)) {
            if (sameYear) "EEE d MMM" else "EEE d MMM yyyy"
        } else {
            if (sameYear) "EEE, MMM d" else "EEE, MMM d, yyyy"
        }
    return wall.format(DateTimeFormatter.ofPattern(pattern, locale))
}

/**
 * A short timestamp, never relative: « dim. 8 nov. · 18:30 », the year only outside the current
 * one. The `shortDateTime` kind of the shared cases.
 */
internal fun formatTimestamp(
    context: Context,
    instant: Instant,
    zone: String?,
    now: Instant = FormatClock.now(),
): String {
    val locale = formatLocale(context)
    val zoneId = zoneOrDevice(zone)
    val wall = instant.atZone(zoneId)
    return context.getString(
        R.string.departure_at,
        formatDay(wall, now.atZone(zoneId), locale),
        formatTime(wall, locale),
    )
}

/**
 * A departure in one string, the single format of the app (BRANDING §8.3, ledger BRAND-8): « sam.
 * 12 avr. · 09:00 », « sam. 10 avr. 2027 · 09:00 », « Aujourd'hui · 09:00 », « Demain · 09:00 ».
 * [isoDateTime] is the contract's UTC instant, read in the [zone] of the ride — « today » and «
 * tomorrow » are that zone's too. Null for a missing or unreadable instant.
 */
internal fun formatDeparture(
    context: Context,
    isoDateTime: String?,
    zone: String? = null,
    now: Instant = FormatClock.now(),
): String? {
    val instant = parseInstant(isoDateTime) ?: return null
    val locale = formatLocale(context)
    val zoneId = zoneOrDevice(zone)
    val wall = instant.atZone(zoneId)
    val reference = now.atZone(zoneId)
    val day =
        when (ChronoUnit.DAYS.between(reference.toLocalDate(), wall.toLocalDate())) {
            0L -> context.getString(R.string.today)
            1L -> context.getString(R.string.tomorrow)
            else -> formatDay(wall, reference, locale)
        }
    return context.getString(R.string.departure_at, day, formatTime(wall, locale))
}

/** The hour of a departure alone, for « Départ 09:30 »: « 09:30 », « 9:30 AM ». */
internal fun formatDepartureTime(context: Context, isoDateTime: String?, zone: String?): String? {
    val instant = parseInstant(isoDateTime) ?: return null
    return formatTime(instant.atZone(zoneOrDevice(zone)), formatLocale(context))
}

/**
 * « Aujourd'hui » or « Demain » when the departure falls on that day in the [zone] of the ride;
 * null otherwise — yesterday included: no other relative day exists (ledger BRAND-8).
 */
internal fun formatRelativeDay(
    context: Context,
    isoDateTime: String?,
    zone: String?,
    now: Instant = FormatClock.now(),
): String? {
    val instant = parseInstant(isoDateTime) ?: return null
    val zoneId = zoneOrDevice(zone)
    val gap =
        ChronoUnit.DAYS.between(
            now.atZone(zoneId).toLocalDate(),
            instant.atZone(zoneId).toLocalDate(),
        )
    return when (gap) {
        0L -> context.getString(R.string.today)
        1L -> context.getString(R.string.tomorrow)
        else -> null
    }
}

/**
 * The lines of the day box (docs/BRANDING.md §7.8): weekday, day, month — « sam. », « 14 », « nov.
 * » — and the year only outside the current one, since on a row the box is the only date.
 */
internal data class DayBoxParts(
    val weekday: String,
    val day: String,
    val month: String,
    val year: String?,
)

internal fun dayBoxParts(
    context: Context,
    isoDateTime: String?,
    zone: String?,
    now: Instant = FormatClock.now(),
): DayBoxParts? {
    val instant = parseInstant(isoDateTime) ?: return null
    val locale = formatLocale(context)
    val zoneId = zoneOrDevice(zone)
    val wall = instant.atZone(zoneId)
    return DayBoxParts(
        weekday = wall.format(DateTimeFormatter.ofPattern("EEE", locale)),
        day = wall.dayOfMonth.toString(),
        month = wall.format(DateTimeFormatter.ofPattern("MMM", locale)),
        year = if (wall.year == now.atZone(zoneId).year) null else wall.year.toString(),
    )
}

/**
 * « heure de Tokyo (ven. 01:00 chez vous) » for a departure whose [zone] is not, at that instant,
 * at the Karoo's offset; null otherwise — nearly always. The reader's day is named only when it
 * differs from the ride's.
 */
internal fun formatZoneMention(
    context: Context,
    isoDateTime: String?,
    zone: String?,
    deviceZone: ZoneId = ZoneId.systemDefault(),
): String? {
    val instant = parseInstant(isoDateTime) ?: return null
    val zoneId = zone?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: return null
    if (zoneId.rules.getOffset(instant) == deviceZone.rules.getOffset(instant)) return null
    val locale = formatLocale(context)
    val french = isFrench(locale)
    val reader = instant.atZone(deviceZone)
    val time = formatTime(reader, locale)
    val sameDay: Boolean = reader.toLocalDate() == LocalDate.from(instant.atZone(zoneId))
    val local =
        if (sameDay) time else "${reader.format(DateTimeFormatter.ofPattern("EEE", locale))} $time"
    return context.getString(
        R.string.zone_mention_with_local,
        context.getString(
            R.string.zone_mention,
            if (french) zoneCityOf(zone, true) else zoneCityName(zone, false),
        ),
        context.getString(R.string.at_your_place, local),
    )
}
