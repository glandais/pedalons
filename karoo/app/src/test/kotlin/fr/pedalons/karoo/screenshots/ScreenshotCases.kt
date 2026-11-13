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
import fr.pedalons.karoo.api.DeviceCodeResponse
import fr.pedalons.karoo.api.DeviceRegisteredGroup
import fr.pedalons.karoo.api.DeviceRegisteredStage
import fr.pedalons.karoo.api.DeviceRide
import fr.pedalons.karoo.api.DeviceRideEntry
import fr.pedalons.karoo.api.DeviceRoute
import fr.pedalons.karoo.api.DeviceRouteSyncStatus
import fr.pedalons.karoo.api.RoutesResponse
import fr.pedalons.karoo.auth.CodeContent
import fr.pedalons.karoo.auth.ErrorContent
import fr.pedalons.karoo.auth.ExpiredContent
import fr.pedalons.karoo.auth.GpsConnectContent
import fr.pedalons.karoo.auth.LoadingContent
import fr.pedalons.karoo.auth.PollingContent
import fr.pedalons.karoo.auth.SuccessContent
import fr.pedalons.karoo.browse.NavState
import fr.pedalons.karoo.browse.SyncState
import fr.pedalons.karoo.browse.ui.ConnectScreen
import fr.pedalons.karoo.browse.ui.EmptyScreen
import fr.pedalons.karoo.browse.ui.ErrorScreen
import fr.pedalons.karoo.browse.ui.HomeScreen
import fr.pedalons.karoo.browse.ui.RegisteredGroupListScreen
import fr.pedalons.karoo.browse.ui.RideEntriesScreen
import fr.pedalons.karoo.browse.ui.RideListScreen
import fr.pedalons.karoo.browse.ui.RouteDetailScreen
import fr.pedalons.karoo.browse.ui.SkeletonScreen
import fr.pedalons.karoo.browse.ui.StandaloneRouteListScreen
import fr.pedalons.karoo.support.TEST_NOW
import fr.pedalons.karoo.ui.FormatClock
import fr.pedalons.karoo.ui.theme.PedalonsKarooTheme
import io.hammerhead.karooext.models.UserProfile
import io.hammerhead.karooext.models.UserProfile.PreferredUnit.UnitType
import java.time.Instant
import java.util.Locale
import java.util.TimeZone
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test

/**
 * Pixel goldens of the Karoo screens on the device's own display: 480x800 px at 300 dpi (the Karoo
 * 3's `wm size` / `wm density`, i.e. 1.875x, 256x427 dp), Android 12 (SDK 32). The screens are
 * rendered one by one from fixed data, so a golden changes only when the pixels of that screen do.
 * Time zone, locale, the 24h setting and the clock are frozen; the clock does not advance, so the
 * indeterminate progress indicators are always drawn at their first frame.
 *
 * Subclasses pick the language. Goldens are recorded by `recordRoborazziDebug` and checked by
 * `verifyRoborazziDebug`; they are re-recorded only for an intended visual change (karoo/CLAUDE.md,
 * « Tests »).
 */
abstract class ScreenshotCases(private val language: String) {

    @get:Rule val compose = createComposeRule()

    private lateinit var savedZone: TimeZone
    private lateinit var savedLocale: Locale
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    @Before
    fun freeze() {
        savedZone = TimeZone.getDefault()
        savedLocale = Locale.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("Europe/Paris"))
        Locale.setDefault(Locale.forLanguageTag(language))
        Settings.System.putString(context.contentResolver, Settings.System.TIME_12_24, "24")
        FormatClock.now = { Instant.parse(TEST_NOW) }
    }

    @After
    fun unfreeze() {
        TimeZone.setDefault(savedZone)
        Locale.setDefault(savedLocale)
        FormatClock.now = Instant::now
    }

    private fun shot(name: String, content: @Composable () -> Unit) {
        // No automatic clock: nothing animates between composition and capture.
        compose.mainClock.autoAdvance = false
        compose.setContent {
            PedalonsKarooTheme {
                // What MainScreen puts around every screen.
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background,
                ) {
                    content()
                }
            }
        }
        compose.onRoot().captureRoboImage("src/test/screenshots/$language/$name.png", options)
    }

    private val options =
        RoborazziOptions(compareOptions = RoborazziOptions.CompareOptions(changeThreshold = 0f))

    // === Data ===

    private fun group(
        name: String,
        ride: String,
        route: String,
        state: String?,
        start: String = "2026-11-14T08:30:00Z",
        km: Float = 42_000f,
        up: Float = 600f,
    ) =
        DeviceRegisteredGroup(
            teamSlug = "team-a",
            rideSlug = "ride-$name",
            rideName = ride,
            groupName = name,
            routeSlug = route,
            routeName = "Route $name",
            distance = km,
            elevationGain = up,
            startDateTime = start,
            timezone = "Europe/Paris",
            syncStatuses = state?.let { listOf(DeviceRouteSyncStatus("HAMMERHEAD", it)) },
        )

    private val groupSent = group("Fast", "Sunday ride", "r1", "SENT")
    private val groupOutdated =
        group("Medium", "Sunday ride", "r2", "OUTDATED", km = 38_500f, up = 410f)
    private val groupPending =
        group(
            "Easy",
            "Evening spin",
            "r3",
            "PENDING",
            start = "2026-11-15T17:00:00Z",
            km = 25_000f,
            up = 150f,
        )
    private val groupFailing =
        group(
            "Hills",
            "Col du Granier with a very long ride name",
            "r4",
            "FAILING",
            km = 61_200f,
            up = 1450f,
        )
    private val groupReconnect = group("Gravel", "Saturday gravel", "r5", "RECONNECT_REQUIRED")
    private val groupUnknown = group("Social", "Coffee ride", "r6", null, km = 18_000f, up = 90f)

    private fun stage(
        name: String,
        route: String,
        state: String?,
        start: String,
        from: String? = null,
        to: String? = null,
        zone: String = "Europe/Paris",
        km: Float = 82_500f,
        up: Float = 2100f,
    ) =
        DeviceRegisteredStage(
            teamSlug = "team-a",
            tripSlug = "trip-1",
            tripName = "Alps crossing",
            stageName = name,
            routeSlug = route,
            routeName = "Route $name",
            distance = km,
            elevationGain = up,
            startDateTime = start,
            timezone = zone,
            startPlaceName = from,
            endPlaceName = to,
            syncStatuses = state?.let { listOf(DeviceRouteSyncStatus("HAMMERHEAD", it)) },
        )

    private val stageOne =
        stage("Stage 1", "st1", "SENT", "2026-11-14T07:00:00Z", "Bourg-d'Oisans", "Valloire")
    private val stageTwo =
        stage("Stage 2", "st2", null, "2026-11-15T07:30:00Z", km = 64_000f, up = 1800f)
    // A ride read from elsewhere: Saturday 08:00 in Tokyo is Friday 23:00 on this Karoo.
    private val groupTokyo =
        group("B", "Tokyo sunrise", "r7", null, start = "2026-11-13T23:00:00Z")
            .copy(
                timezone = "Asia/Tokyo",
            )

    private fun entry(
        slug: String,
        name: String,
        group: String?,
        km: Float,
        up: Float,
        start: String?,
    ) = DeviceRideEntry(slug, name, group, km, up, null, null, start)

    private val rideTwoEntries =
        DeviceRide(
            "team-a",
            "ride-1",
            "Sunday ride",
            "2026-11-14T08:00:00Z",
            listOf(
                entry("r1", "Col de Porte", "Fast", 42_000f, 600f, "2026-11-14T08:30:00Z"),
                entry("r2", "Chartreuse loop", "Easy", 25_000f, 200f, null),
                entry(
                    "r3",
                    "Route without a group name that is quite long",
                    null,
                    61_000f,
                    1500f,
                    null,
                ),
            ),
        )
    private val rideSingle =
        DeviceRide(
            "team-a",
            "ride-2",
            "Saturday spin",
            "2026-11-15T07:00:00Z",
            listOf(entry("r4", "Canal loop", null, 15_000f, 50f, null)),
        )
    private val rideUndated =
        DeviceRide(
            "team-b",
            "ride-3",
            "Undated ride with a name too long for one line",
            null,
            listOf(entry("r5", "X", null, 1f, 1f, null), entry("r6", "Y", null, 1f, 1f, null)),
        )

    private val routes =
        listOf(
            DeviceRoute("team-a", "s1", "Solo loop", 30_000f, 300f),
            DeviceRoute("team-a", "s2", "Lake tour with a name that does not fit", 50_000f, 450f),
            DeviceRoute("team-b", "s3", "Hill climb", 20_000f, 1200f),
        )

    private fun response(
        rides: List<DeviceRide>,
        routes: List<DeviceRoute>,
        groups: List<DeviceRegisteredGroup>,
    ) = RoutesResponse(rides, routes, groups)

    private val imperial =
        UserProfile(
            70f,
            UserProfile.PreferredUnit(
                UnitType.IMPERIAL,
                UnitType.IMPERIAL,
                UnitType.IMPERIAL,
                UnitType.IMPERIAL,
            ),
            190,
            50,
            emptyList(),
            250,
            emptyList(),
        )

    private val detail =
        NavState.RouteDetail("team-a", "r1", "Col de Porte", 42_000f, 600f, "2026-11-14T08:30:00Z")
    private val detailNoDate =
        NavState.RouteDetail(
            "team-a",
            "s2",
            "Lake tour with a name that does not fit on a single line",
            50_000f,
            450f,
            null,
        )

    // === Shared screens ===

    @Test fun connect() = shot("connect") { ConnectScreen(onConnect = {}, onBack = {}) }

    @Test fun skeleton() = shot("skeleton") { SkeletonScreen(onBack = {}) }

    @Test fun error() = shot("error") { ErrorScreen(onRetry = {}, onBack = {}) }

    @Test fun empty() = shot("empty") { EmptyScreen(onBack = {}) }

    // === Home ===

    @Test
    fun home_withRides() =
        shot("home_with_rides") {
            HomeScreen(
                response(
                    listOf(rideTwoEntries, rideSingle),
                    routes,
                    listOf(groupSent, groupPending),
                ),
                0,
                rememberLazyListState(),
                {},
                {},
                {},
                {},
            )
        }

    @Test
    fun home_withRides_secondSelected() =
        shot("home_with_rides_selected_2") {
            HomeScreen(
                response(
                    listOf(rideTwoEntries, rideSingle),
                    routes,
                    listOf(groupSent, groupPending),
                ),
                1,
                rememberLazyListState(),
                {},
                {},
                {},
                {},
            )
        }

    @Test
    fun home_withoutRides() =
        shot("home_without_rides") {
            HomeScreen(
                response(emptyList(), routes, listOf(groupSent)),
                1,
                rememberLazyListState(),
                {},
                {},
                {},
                {},
            )
        }

    @Test
    fun home_allEmpty() =
        shot("home_all_empty") {
            HomeScreen(
                response(emptyList(), emptyList(), emptyList()),
                0,
                rememberLazyListState(),
                {},
                {},
                {},
                {},
            )
        }

    // === Registered groups ===

    @Test
    fun registered_serverStates_1() =
        shot("registered_server_states_1") {
            RegisteredGroupListScreen(
                listOf(groupSent, groupOutdated, groupPending),
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
    fun registered_serverStates_2() =
        shot("registered_server_states_2") {
            RegisteredGroupListScreen(
                listOf(groupFailing, groupReconnect, groupUnknown),
                null,
                1,
                rememberLazyListState(),
                SyncState.IDLE,
                null,
                emptySet(),
                { _, _ -> },
                {},
            )
        }

    @Test
    fun registered_syncing() =
        shot("registered_syncing") {
            RegisteredGroupListScreen(
                listOf(groupSent, groupOutdated, groupPending),
                null,
                1,
                rememberLazyListState(),
                SyncState.SYNCING,
                1,
                emptySet(),
                { _, _ -> },
                {},
            )
        }

    @Test
    fun registered_success() =
        shot("registered_success") {
            RegisteredGroupListScreen(
                listOf(groupSent, groupOutdated, groupPending),
                null,
                1,
                rememberLazyListState(),
                SyncState.SUCCESS,
                1,
                setOf("team-a/r2"),
                { _, _ -> },
                {},
            )
        }

    @Test
    fun registered_error() =
        shot("registered_error") {
            RegisteredGroupListScreen(
                listOf(groupSent, groupOutdated, groupPending),
                null,
                2,
                rememberLazyListState(),
                SyncState.ERROR,
                2,
                emptySet(),
                { _, _ -> },
                {},
            )
        }

    @Test
    fun registered_syncedThisSession() =
        shot("registered_synced_this_session") {
            // The server still says OUTDATED / PENDING for these two, but they were sent from this
            // Karoo.
            RegisteredGroupListScreen(
                listOf(groupSent, groupOutdated, groupPending),
                null,
                0,
                rememberLazyListState(),
                SyncState.IDLE,
                null,
                setOf("team-a/r2", "team-a/r3"),
                { _, _ -> },
                {},
            )
        }

    @Test
    fun registered_imperial() =
        shot("registered_imperial") {
            RegisteredGroupListScreen(
                listOf(groupSent, groupFailing),
                imperial,
                0,
                rememberLazyListState(),
                SyncState.IDLE,
                null,
                emptySet(),
                { _, _ -> },
                {},
            )
        }

    // A trip stage beside a ride group, by departure (docs/LEDGER_*.md API-168).
    @Test
    fun registered_withStages() =
        shot("registered_with_stages") {
            RegisteredGroupListScreen(
                listOf(stageOne, groupSent, stageTwo),
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

    // A short group name, and a departure in another zone than the Karoo's.
    @Test
    fun registered_otherZone() =
        shot("registered_other_zone") {
            RegisteredGroupListScreen(
                listOf(groupTokyo, groupUnknown),
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
    fun registered_empty() =
        shot("registered_empty") {
            RegisteredGroupListScreen(
                emptyList(),
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

    // === Rides ===

    @Test
    fun rideList() =
        shot("ride_list") {
            RideListScreen(
                listOf(rideTwoEntries, rideSingle, rideUndated),
                1,
                rememberLazyListState(),
                {},
                {},
            )
        }

    @Test
    fun rideList_empty() =
        shot("ride_list_empty") { RideListScreen(emptyList(), 0, rememberLazyListState(), {}, {}) }

    @Test
    fun rideEntries() =
        shot("ride_entries") {
            RideEntriesScreen(rideTwoEntries, null, 0, rememberLazyListState(), {}, {})
        }

    @Test
    fun rideEntries_imperial() =
        shot("ride_entries_imperial") {
            RideEntriesScreen(rideTwoEntries, imperial, 2, rememberLazyListState(), {}, {})
        }

    // === Routes ===

    @Test
    fun routeList() =
        shot("route_list") {
            StandaloneRouteListScreen(routes, null, 1, rememberLazyListState(), {}, {})
        }

    @Test
    fun routeList_imperial() =
        shot("route_list_imperial") {
            StandaloneRouteListScreen(routes, imperial, 0, rememberLazyListState(), {}, {})
        }

    @Test
    fun routeList_empty() =
        shot("route_list_empty") {
            StandaloneRouteListScreen(emptyList(), null, 0, rememberLazyListState(), {}, {})
        }

    // === Route detail ===

    @Test
    fun routeDetail_idle() =
        shot("route_detail_idle") { RouteDetailScreen(detail, null, SyncState.IDLE, {}, {}) }

    @Test
    fun routeDetail_syncing() =
        shot("route_detail_syncing") { RouteDetailScreen(detail, null, SyncState.SYNCING, {}, {}) }

    @Test
    fun routeDetail_success() =
        shot("route_detail_success") { RouteDetailScreen(detail, null, SyncState.SUCCESS, {}, {}) }

    @Test
    fun routeDetail_error() =
        shot("route_detail_error") { RouteDetailScreen(detail, null, SyncState.ERROR, {}, {}) }

    @Test
    fun routeDetail_noDateLongName_imperial() =
        shot("route_detail_no_date_long_name_imperial") {
            RouteDetailScreen(detailNoDate, imperial, SyncState.IDLE, {}, {})
        }

    // === Sign-in (AuthActivity) ===

    private val code =
        DeviceCodeResponse(
            deviceCode = "device-code",
            userCode = "ABC123",
            verificationUri = "https://www.pedalons.fr/karoo",
            verificationUriComplete = "https://www.pedalons.fr/karoo?code=ABC123",
            expiresIn = 600,
            interval = 5,
        )

    @Test fun auth_loading() = shot("auth_loading") { LoadingContent() }

    @Test fun auth_code() = shot("auth_code") { CodeContent(code) }

    @Test fun auth_polling() = shot("auth_polling") { PollingContent("ABC123") }

    @Test fun auth_success() = shot("auth_success") { SuccessContent() }

    @Test
    fun auth_error() = shot("auth_error") { ErrorContent("Access denied by the account owner", {}) }

    @Test fun auth_expired() = shot("auth_expired") { ExpiredContent({}) }

    // === Hammerhead step (GpsConnectActivity) ===

    @Test
    fun gpsConnect() =
        shot("gps_connect") {
            GpsConnectContent("https://www.pedalons.fr/karoo/hammerhead", {})
        }
}
