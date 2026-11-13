package fr.pedalons.karoo.screenshots

import android.provider.Settings
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.RoborazziOptions
import com.github.takahirom.roborazzi.captureRoboImage
import fr.pedalons.karoo.api.DeviceRegisteredGroup
import fr.pedalons.karoo.api.DeviceRegisteredStage
import fr.pedalons.karoo.api.DeviceRide
import fr.pedalons.karoo.api.DeviceRideEntry
import fr.pedalons.karoo.api.DeviceRoute
import fr.pedalons.karoo.api.DeviceRouteSyncStatus
import fr.pedalons.karoo.browse.NavState
import fr.pedalons.karoo.browse.SyncState
import fr.pedalons.karoo.browse.ui.RegisteredGroupListScreen
import fr.pedalons.karoo.browse.ui.RideEntriesScreen
import fr.pedalons.karoo.browse.ui.RouteDetailScreen
import fr.pedalons.karoo.browse.ui.StandaloneRouteListScreen
import fr.pedalons.karoo.support.TEST_NOW
import fr.pedalons.karoo.ui.FormatClock
import fr.pedalons.karoo.ui.theme.PedalonsKarooTheme
import java.time.Instant
import java.util.Locale
import java.util.TimeZone
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The screenshots of the extension's listing (`karoo/metadata/screenshots/`, published with every
 * release and listed in `metadata/app.json`): the real screens on demo data, at the Karoo's own
 * 480x800. Rendered here rather than taken on a device so that they follow the app — they are
 * goldens like the others: a visual change fails `verifyRoborazziDebug` until they are re-recorded
 * (`recordRoborazziDebug`), and a release can no longer ship the screens of the version before.
 *
 * `qrcode.png` is not here: the sign-in screen is still the device capture of October 2026.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "en-w256dp-h427dp-300dpi")
class StoreScreenshotsTest {

    @get:Rule val compose = createComposeRule()

    private lateinit var savedZone: TimeZone
    private lateinit var savedLocale: Locale
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    @Before
    fun freeze() {
        savedZone = TimeZone.getDefault()
        savedLocale = Locale.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("Europe/Paris"))
        Locale.setDefault(Locale.ENGLISH)
        Settings.System.putString(context.contentResolver, Settings.System.TIME_12_24, "24")
        FormatClock.now = { Instant.parse(TEST_NOW) }
    }

    @After
    fun unfreeze() {
        TimeZone.setDefault(savedZone)
        Locale.setDefault(savedLocale)
        FormatClock.now = Instant::now
    }

    private val options =
        RoborazziOptions(compareOptions = RoborazziOptions.CompareOptions(changeThreshold = 0f))

    private fun shot(name: String, content: @Composable () -> Unit) {
        compose.mainClock.autoAdvance = false
        compose.setContent {
            PedalonsKarooTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background,
                ) {
                    content()
                }
            }
        }
        // The working directory of the module's tests is karoo/app.
        compose.onRoot().captureRoboImage("../metadata/screenshots/$name.png", options)
    }

    private fun sent() = listOf(DeviceRouteSyncStatus("HAMMERHEAD", "SENT"))

    // « Now » is Wednesday 11 November 2026: Thursday's ride is « Tomorrow ».
    private val nextRides =
        listOf(
            DeviceRegisteredGroup(
                teamSlug = "annecy",
                rideSlug = "thursday",
                rideName = "Thursday ride",
                groupName = "B",
                routeSlug = "semnoz",
                routeName = "Semnoz and Col de Leschaux",
                distance = 52_400f,
                elevationGain = 1304f,
                startDateTime = "2026-11-12T17:00:00Z",
                timezone = "Europe/Paris",
                syncStatuses = sent(),
                teamName = "Annecy Cycling",
                startPlaceName = "Town hall",
                status = "PUBLISHED",
                endDateTime = "2026-11-12T19:30:00Z",
            ),
            DeviceRegisteredStage(
                teamSlug = "annecy",
                tripSlug = "beaufortain",
                tripName = "Beaufortain weekend",
                stageName = "Stage 1",
                routeSlug = "annecy-beaufort",
                routeName = "Annecy to Beaufort",
                distance = 65_500f,
                elevationGain = 806f,
                startDateTime = "2026-11-14T07:30:00Z",
                timezone = "Europe/Paris",
                startPlaceName = "Annecy",
                endPlaceName = "Beaufort",
                syncStatuses = emptyList(),
                teamName = "Annecy Cycling",
                status = "PUBLISHED",
                endDateTime = "2026-11-14T11:30:00Z",
            ),
            DeviceRegisteredStage(
                teamSlug = "annecy",
                tripSlug = "beaufortain",
                tripName = "Beaufortain weekend",
                stageName = "Stage 2",
                routeSlug = "cormet",
                routeName = "Beaufort to Cormet de Roselend",
                distance = 41_900f,
                elevationGain = 1425f,
                startDateTime = "2026-11-15T08:00:00Z",
                timezone = "Europe/Paris",
                startPlaceName = "Beaufort",
                endPlaceName = "Cormet de Roselend",
                syncStatuses = emptyList(),
                teamName = "Annecy Cycling",
                status = "PUBLISHED",
                endDateTime = "2026-11-15T11:30:00Z",
            ),
        )

    private fun entry(slug: String, name: String, group: String?, start: String) =
        DeviceRideEntry(slug, name, group, 76_100f, 1527f, null, null, start)

    private val saturdayRide =
        DeviceRide(
            "annecy",
            "saturday",
            "Saturday ride: Bauges loop",
            "2026-11-14T07:30:00Z",
            listOf(
                entry("bauges", "Bauges loop", null, "2026-11-14T07:30:00Z"),
                entry("bauges", "Bauges loop", "Fast group", "2026-11-14T07:30:00Z"),
                entry("bauges", "Bauges loop", "Intermediate group", "2026-11-14T07:45:00Z"),
                entry("bauges", "Bauges loop", "Recovery group", "2026-11-14T07:45:00Z"),
            ),
            "Europe/Paris",
        )

    private val routes =
        listOf(
            DeviceRoute("annecy", "cormet", "Beaufort to Cormet de Roselend", 41_900f, 1425f),
            DeviceRoute("annecy", "annecy-beaufort", "Annecy to Beaufort", 65_500f, 806f),
            DeviceRoute("annecy", "glieres", "Glières plateau gravel", 28_400f, 1059f),
            DeviceRoute("annecy", "bauges", "Bauges loop", 76_100f, 1527f),
            DeviceRoute("annecy", "semnoz", "Semnoz and Col de Leschaux", 52_400f, 1304f),
        )

    @Test
    fun nextRides() =
        shot("next-rides") {
            RegisteredGroupListScreen(
                nextRides,
                null,
                0,
                rememberLazyListState(),
                SyncState.IDLE,
                null,
                emptySet(),
                { _, _ -> },
                {},
            )
        }

    @Test
    fun ride() =
        shot("ride") {
            RideEntriesScreen(saturdayRide, null, 0, rememberLazyListState(), {}, {})
        }

    @Test
    fun routes() =
        shot("routes") {
            StandaloneRouteListScreen(routes, null, 0, rememberLazyListState(), {}, {})
        }

    @Test
    fun downloaded() =
        shot("downloaded") {
            RouteDetailScreen(
                NavState.RouteDetail.of(saturdayRide, saturdayRide.entries[0]),
                null,
                SyncState.SUCCESS,
                {},
                {},
            )
        }
}
