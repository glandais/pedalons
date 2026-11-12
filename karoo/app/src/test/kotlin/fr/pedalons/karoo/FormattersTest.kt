package fr.pedalons.karoo

import android.content.Context
import android.provider.Settings
import androidx.test.core.app.ApplicationProvider
import fr.pedalons.karoo.ui.formatDateTime
import fr.pedalons.karoo.ui.formatDistance
import fr.pedalons.karoo.ui.formatElevation
import io.hammerhead.karooext.models.UserProfile
import io.hammerhead.karooext.models.UserProfile.PreferredUnit.UnitType
import java.util.Locale
import java.util.TimeZone
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "en")
class FormattersTest {

    private val context: Context = ApplicationProvider.getApplicationContext()
    private lateinit var savedZone: TimeZone
    private lateinit var savedLocale: Locale

    @Before
    fun freeze() {
        savedZone = TimeZone.getDefault()
        savedLocale = Locale.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("Europe/Paris"))
        Locale.setDefault(Locale.US)
        set24h(true)
    }

    @After
    fun restore() {
        TimeZone.setDefault(savedZone)
        Locale.setDefault(savedLocale)
    }

    private fun set24h(on: Boolean) {
        Settings.System.putString(
            context.contentResolver,
            Settings.System.TIME_12_24,
            if (on) "24" else "12",
        )
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

    // === formatDistance ===

    @Test
    fun distance_metricByDefaultWithoutProfile() {
        assertEquals("42.0 km", formatDistance(context, 42_000f, null))
        assertEquals("0.0 km", formatDistance(context, 0f, null))
        assertEquals("12.3 km", formatDistance(context, 12_345f, null))
    }

    @Test
    fun distance_metricProfile() {
        val p = profile(UnitType.METRIC, UnitType.IMPERIAL)
        assertEquals("1.5 km", formatDistance(context, 1_500f, p))
    }

    @Test
    fun distance_imperialFollowsTheDistanceUnitOnly() {
        val p = profile(UnitType.IMPERIAL, UnitType.METRIC)
        assertEquals("1.0 mi", formatDistance(context, 1609.344f, p))
        assertEquals("26.1 mi", formatDistance(context, 42_000f, p))
    }

    // === formatElevation ===

    @Test
    fun elevation_metricByDefaultAndTruncatesToWholeMeters() {
        assertEquals("↑600m", formatElevation(context, 600f, null))
        assertEquals("↑599m", formatElevation(context, 599.9f, null))
        assertEquals("↑0m", formatElevation(context, 0f, null))
    }

    @Test
    fun elevation_imperialFollowsTheElevationUnitOnly() {
        val p = profile(UnitType.METRIC, UnitType.IMPERIAL)
        assertEquals("↑1968ft", formatElevation(context, 600f, p))
        assertEquals("↑0ft", formatElevation(context, 0f, p))
        // The distance unit is independent.
        assertEquals(
            "↑600m",
            formatElevation(context, 600f, profile(UnitType.IMPERIAL, UnitType.METRIC)),
        )
    }

    // === formatDateTime ===

    @Test
    fun dateTime_24hInTheDeviceZone() {
        // 08:30 UTC is 09:30 in Paris in November.
        assertEquals("11/14/26 09:30", formatDateTime(context, "2026-11-14T08:30:00Z"))
    }

    @Test
    fun dateTime_12h() {
        set24h(false)
        assertEquals("11/14/26 9:30 AM", formatDateTime(context, "2026-11-14T08:30:00Z"))
        assertEquals("11/14/26 9:30 PM", formatDateTime(context, "2026-11-14T20:30:00Z"))
    }

    @Test
    fun dateTime_followsTheDeviceZoneInSummerToo() {
        assertEquals("7/14/26 10:30", formatDateTime(context, "2026-07-14T08:30:00Z"))
    }

    @Test
    fun dateTime_dateCanRollOverInTheLocalZone() {
        assertEquals("11/15/26 00:30", formatDateTime(context, "2026-11-14T23:30:00Z"))
    }

    @Test
    fun dateTime_nullBlankAndInvalidGiveNull() {
        assertNull(formatDateTime(context, null))
        assertNull(formatDateTime(context, ""))
        assertNull(formatDateTime(context, "   "))
        assertNull(formatDateTime(context, "not a date"))
        assertNull(formatDateTime(context, "2026-11-14"))
        assertNull(formatDateTime(context, "2026-11-14T08:30:00"))
    }

    @Test
    fun dateTime_frenchLocaleUsesTheLocalDateStyle() {
        Locale.setDefault(Locale.FRANCE)
        assertEquals("14/11/2026 09:30", formatDateTime(context, "2026-11-14T08:30:00Z"))
    }
}
