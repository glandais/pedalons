package fr.pedalons.karoo

import android.content.Context
import android.content.res.Configuration
import androidx.test.core.app.ApplicationProvider
import fr.pedalons.karoo.ui.formatDeparture
import fr.pedalons.karoo.ui.formatDistance
import fr.pedalons.karoo.ui.formatElevationGain
import fr.pedalons.karoo.ui.formatZoneMention
import io.hammerhead.karooext.models.UserProfile
import io.hammerhead.karooext.models.UserProfile.PreferredUnit.UnitType
import java.time.Instant
import java.time.ZoneId
import java.util.Locale
import java.util.TimeZone
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The formats of the Karoo, in the words of the app and the site (docs/LEDGER_*.md API-191). The
 * values shared by the three are in `FormatCasesTest`; here, what belongs to the Karoo: the units
 * of the rider's profile, the relative days, the zone of the ride and its mention.
 */
@RunWith(RobolectricTestRunner::class)
class FormattersTest {

    private val base: Context = ApplicationProvider.getApplicationContext()
    private val en = localized("en")
    private val fr = localized("fr")
    private val now = Instant.parse("2026-11-11T12:00:00Z")
    private val paris = ZoneId.of("Europe/Paris")
    private lateinit var savedZone: TimeZone

    private fun localized(language: String): Context =
        base.createConfigurationContext(
            Configuration(base.resources.configuration).apply {
                setLocale(Locale.forLanguageTag(language))
            },
        )

    @Before
    fun freeze() {
        savedZone = TimeZone.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("Europe/Paris"))
    }

    @After
    fun restore() {
        TimeZone.setDefault(savedZone)
    }

    private fun profile(distance: UnitType, elevation: UnitType) =
        UserProfile(
            weight = 70f,
            preferredUnit =
                UserProfile.PreferredUnit(distance, elevation, UnitType.METRIC, UnitType.METRIC),
            maxHr = 190,
            restingHr = 50,
            heartRateZones = emptyList(),
            ftp = 250,
            powerZones = emptyList(),
        )

    // === Distance ===

    @Test
    fun distance_metricByDefaultWithoutProfile() {
        assertEquals("42.0 km", formatDistance(en, 42_000f, null))
        assertEquals("0.0 km", formatDistance(en, 0f, null))
        assertEquals("12.3 km", formatDistance(en, 12_345f, null))
    }

    @Test
    fun distance_followsTheLanguageOfTheTexts() {
        assertEquals("42,0 km", formatDistance(fr, 42_000f, null))
    }

    @Test
    fun distance_imperialFollowsTheDistanceUnitOnly() {
        val p = profile(UnitType.IMPERIAL, UnitType.METRIC)
        assertEquals("1.0 mi", formatDistance(en, 1609.344f, p))
        assertEquals("26.1 mi", formatDistance(en, 42_000f, p))
        assertEquals(
            "1.5 km",
            formatDistance(en, 1_500f, profile(UnitType.METRIC, UnitType.IMPERIAL)),
        )
    }

    // === Elevation gain ===

    @Test
    fun elevationGain_isRoundedGroupedAndNamed() {
        assertEquals("600 m D+", formatElevationGain(fr, 600f, null))
        assertEquals("600 m D+", formatElevationGain(fr, 599.9f, null))
        assertEquals("1 240 m D+", formatElevationGain(fr, 1240f, null))
        assertEquals("1,240 m D+", formatElevationGain(en, 1240f, null))
        assertEquals("0 m D+", formatElevationGain(fr, 0f, null))
    }

    @Test
    fun elevationGain_imperialFollowsTheElevationUnitOnly() {
        val p = profile(UnitType.METRIC, UnitType.IMPERIAL)
        assertEquals("1 969 ft D+", formatElevationGain(fr, 600f, p))
        // The distance unit is independent.
        assertEquals(
            "600 m D+",
            formatElevationGain(fr, 600f, profile(UnitType.IMPERIAL, UnitType.METRIC)),
        )
    }

    // === Departure ===

    @Test
    fun departure_isTheShortDateAndTheTimeOfTheLanguage() {
        assertEquals(
            "sam. 14 nov. · 09:30",
            formatDeparture(fr, "2026-11-14T08:30:00Z", "Europe/Paris", now),
        )
        assertEquals(
            "Sat, Nov 14 · 9:30 AM",
            formatDeparture(en, "2026-11-14T08:30:00Z", "Europe/Paris", now),
        )
        assertEquals(
            "Sat, Nov 14 · 9:30 PM",
            formatDeparture(en, "2026-11-14T20:30:00Z", "Europe/Paris", now),
        )
    }

    @Test
    fun departure_saysTodayAndTomorrowAndNothingElseRelative() {
        assertEquals(
            "Aujourd'hui · 18:00",
            formatDeparture(fr, "2026-11-11T17:00:00Z", "Europe/Paris", now),
        )
        assertEquals(
            "Demain · 09:00",
            formatDeparture(fr, "2026-11-12T08:00:00Z", "Europe/Paris", now),
        )
        assertEquals(
            "Tomorrow · 9:00 AM",
            formatDeparture(en, "2026-11-12T08:00:00Z", "Europe/Paris", now),
        )
        // Yesterday has no word.
        assertEquals(
            "mar. 10 nov. · 09:00",
            formatDeparture(fr, "2026-11-10T08:00:00Z", "Europe/Paris", now),
        )
    }

    @Test
    fun departure_carriesTheYearOnlyOutsideTheCurrentOne() {
        assertEquals(
            "sam. 10 avr. 2027 · 09:00",
            formatDeparture(fr, "2027-04-10T07:00:00Z", "Europe/Paris", now),
        )
        assertEquals(
            "Sat, Apr 10, 2027 · 9:00 AM",
            formatDeparture(en, "2027-04-10T07:00:00Z", "Europe/Paris", now),
        )
    }

    @Test
    fun departure_isReadInTheZoneOfTheRide_notTheKaroo() {
        // 23:00 UTC on the 14th: Sunday 08:00 in Tokyo, Sunday 00:00 in Paris.
        assertEquals(
            "dim. 15 nov. · 08:00",
            formatDeparture(fr, "2026-11-14T23:00:00Z", "Asia/Tokyo", now),
        )
        // « Tomorrow » is the ride's tomorrow: the 12th has begun in Tokyo, not yet in Paris.
        assertEquals(
            "Aujourd'hui · 23:30",
            formatDeparture(
                fr,
                "2026-11-12T14:30:00Z",
                "Asia/Tokyo",
                Instant.parse("2026-11-11T16:00:00Z"),
            ),
        )
    }

    @Test
    fun departure_withoutAZoneFallsBackOnTheKaroo() {
        // An older server sends no zone; an unknown one is treated the same.
        assertEquals("sam. 14 nov. · 09:30", formatDeparture(fr, "2026-11-14T08:30:00Z", null, now))
        assertEquals(
            "sam. 14 nov. · 09:30",
            formatDeparture(fr, "2026-11-14T08:30:00Z", "Mars/Olympus", now),
        )
        // Summer time of the Karoo's zone.
        assertEquals(
            "mar. 14 juil. · 10:30",
            formatDeparture(fr, "2026-07-14T08:30:00Z", null, now),
        )
    }

    @Test
    fun departure_nullBlankAndInvalidGiveNull() {
        assertNull(formatDeparture(fr, null))
        assertNull(formatDeparture(fr, ""))
        assertNull(formatDeparture(fr, "   "))
        assertNull(formatDeparture(fr, "not a date"))
        assertNull(formatDeparture(fr, "2026-11-14"))
        assertNull(formatDeparture(fr, "2026-11-14T08:30:00"))
    }

    // === Zone mention ===

    @Test
    fun zoneMention_isSilentAtTheSameOffset() {
        assertNull(formatZoneMention(fr, "2026-11-14T08:30:00Z", "Europe/Paris", paris))
        // Another zone, the same offset that day.
        assertNull(formatZoneMention(fr, "2026-11-14T08:30:00Z", "Europe/Berlin", paris))
        assertNull(formatZoneMention(fr, "2026-11-14T08:30:00Z", null, paris))
        assertNull(formatZoneMention(fr, null, "Asia/Tokyo", paris))
    }

    @Test
    fun zoneMention_namesTheCityAndTheReadersTime() {
        // Saturday 08:00 in Tokyo is Saturday 00:00 in Paris: the same day, no weekday.
        assertEquals(
            "heure de Tokyo (00:00 chez vous)",
            formatZoneMention(fr, "2026-11-13T23:00:00Z", "Asia/Tokyo", paris),
        )
        // Saturday 07:00 in Tokyo is Friday 23:00 in Paris: the reader's day is named.
        assertEquals(
            "heure de Tokyo (ven. 23:00 chez vous)",
            formatZoneMention(fr, "2026-11-13T22:00:00Z", "Asia/Tokyo", paris),
        )
        assertEquals(
            "Tokyo time (Fri 11:00 PM your time)",
            formatZoneMention(en, "2026-11-13T22:00:00Z", "Asia/Tokyo", paris),
        )
        assertEquals(
            "heure de Londres (10:30 chez vous)",
            formatZoneMention(fr, "2026-11-14T09:30:00Z", "Europe/London", paris),
        )
    }
}
