package fr.pedalons.karoo.api

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ModelsTest {

    private fun entry(start: String? = null) =
        DeviceRideEntry(
            routeSlug = "r",
            routeName = "R",
            distance = 1f,
            elevationGain = 1f,
            startDateTime = start,
        )

    private fun ride(start: String? = null, vararg entries: DeviceRideEntry) =
        DeviceRide("t", "ride", "Ride", start, entries.toList())

    // === DeviceRide.startOf ===

    @Test
    fun startOf_prefersTheEntrysOwnStart() {
        val e = entry("2026-11-14T08:30:00Z")
        assertEquals("2026-11-14T08:30:00Z", ride("2026-11-14T08:00:00Z", e).startOf(e))
    }

    @Test
    fun startOf_fallsBackToTheRideStart() {
        val e = entry(null)
        assertEquals("2026-11-14T08:00:00Z", ride("2026-11-14T08:00:00Z", e).startOf(e))
    }

    @Test
    fun startOf_isNullWhenNeitherHasOne() {
        val e = entry(null)
        assertNull(ride(null, e).startOf(e))
    }

    // === RouteSyncState.parse ===

    @Test
    fun parse_knowsEveryState() {
        assertEquals(RouteSyncState.SENT, RouteSyncState.parse("SENT"))
        assertEquals(RouteSyncState.OUTDATED, RouteSyncState.parse("OUTDATED"))
        assertEquals(RouteSyncState.PENDING, RouteSyncState.parse("PENDING"))
        assertEquals(RouteSyncState.FAILING, RouteSyncState.parse("FAILING"))
        assertEquals(RouteSyncState.RECONNECT_REQUIRED, RouteSyncState.parse("RECONNECT_REQUIRED"))
        assertEquals(5, RouteSyncState.entries.size)
    }

    @Test
    fun parse_ignoresUnknownCaseSensitiveAndBlank() {
        assertNull(RouteSyncState.parse("sent"))
        assertNull(RouteSyncState.parse("SOMETHING_NEW"))
        assertNull(RouteSyncState.parse(""))
    }

    // === DeviceRegisteredGroup.hammerheadSyncState ===

    private fun group(statuses: List<DeviceRouteSyncStatus>?) =
        DeviceRegisteredGroup(
            teamSlug = "t",
            rideSlug = "r",
            rideName = "Ride",
            groupName = "G",
            routeSlug = "rs",
            routeName = "Route",
            distance = 1f,
            elevationGain = 1f,
            startDateTime = "2026-11-14T08:30:00Z",
            syncStatuses = statuses,
        )

    @Test
    fun hammerheadSyncState_nullWhenTheServerSentNoStatuses() {
        assertNull(group(null).hammerheadSyncState())
    }

    @Test
    fun hammerheadSyncState_nullWhenHammerheadDoesNotHoldTheRoute() {
        assertNull(group(emptyList()).hammerheadSyncState())
        assertNull(group(listOf(DeviceRouteSyncStatus("GARMIN", "SENT"))).hammerheadSyncState())
    }

    @Test
    fun hammerheadSyncState_readsTheHammerheadEntryAmongOthers() {
        val g =
            group(
                listOf(
                    DeviceRouteSyncStatus("GARMIN", "FAILING"),
                    DeviceRouteSyncStatus(GPS_SERVICE_HAMMERHEAD, "OUTDATED"),
                ),
            )
        assertEquals(RouteSyncState.OUTDATED, g.hammerheadSyncState())
    }

    @Test
    fun hammerheadSyncState_nullForAStateThisBuildDoesNotKnow() {
        assertNull(
            group(listOf(DeviceRouteSyncStatus("HAMMERHEAD", "BRAND_NEW"))).hammerheadSyncState(),
        )
    }

    @Test
    fun hammerheadSyncState_firstHammerheadEntryWins() {
        val g =
            group(
                listOf(
                    DeviceRouteSyncStatus("HAMMERHEAD", "PENDING"),
                    DeviceRouteSyncStatus("HAMMERHEAD", "SENT"),
                ),
            )
        assertEquals(RouteSyncState.PENDING, g.hammerheadSyncState())
    }

    @Test
    fun hammerheadSyncState_serviceTypeIsCaseSensitive() {
        assertNull(group(listOf(DeviceRouteSyncStatus("hammerhead", "SENT"))).hammerheadSyncState())
    }

    // === UserStatusResponse.isHammerheadConnected ===

    // === RoutesResponse.registeredItems (API-168) ===

    private fun stage(name: String, start: String, trip: String = "alps") =
        DeviceRegisteredStage(
            teamSlug = "t",
            tripSlug = trip,
            tripName = "Trip",
            stageName = name,
            routeSlug = "rs-$name",
            routeName = "Route",
            distance = 1f,
            elevationGain = 1f,
            startDateTime = start,
        )

    @Test
    fun registeredItems_withoutStagesIsTheServersOrderOfTheGroups() {
        val late = group(null).copy(groupName = "Late", startDateTime = "2026-11-15T08:00:00Z")
        val early = group(null).copy(groupName = "Early", startDateTime = "2026-11-14T08:00:00Z")
        val response = RoutesResponse(emptyList(), emptyList(), listOf(late, early))
        assertEquals(listOf(late, early), response.registeredItems())
    }

    @Test
    fun registeredItems_mixesGroupsAndStagesByDeparture() {
        val g = group(null).copy(startDateTime = "2026-11-14T08:30:00Z")
        val before = stage("S1", "2026-11-14T07:00:00Z")
        // Milliseconds in the instant: the order is that of the instants, not of the texts.
        val after = stage("S2", "2026-11-14T08:30:00.500Z")
        val response = RoutesResponse(emptyList(), emptyList(), listOf(g), listOf(after, before))
        assertEquals(listOf(before, g, after), response.registeredItems())
    }

    @Test
    fun registrationCount_countsATripOnceWhateverItsStages() {
        val response =
            RoutesResponse(
                emptyList(),
                emptyList(),
                listOf(group(null)),
                listOf(
                    stage("S1", "2026-11-14T07:00:00Z"),
                    stage("S2", "2026-11-15T07:00:00Z"),
                    stage("Other", "2026-11-16T07:00:00Z", trip = "pyrenees"),
                ),
            )
        assertEquals(3, response.registrationCount())
        assertEquals(4, response.registeredItems().size)
    }

    @Test
    fun isHammerheadConnected() {
        assertTrue(UserStatusResponse(listOf("HAMMERHEAD")).isHammerheadConnected())
        assertTrue(UserStatusResponse(listOf("GARMIN", "HAMMERHEAD")).isHammerheadConnected())
        assertFalse(UserStatusResponse(emptyList()).isHammerheadConnected())
        assertFalse(UserStatusResponse(listOf("GARMIN")).isHammerheadConnected())
        assertFalse(UserStatusResponse(listOf("hammerhead")).isHammerheadConnected())
    }

    // === Request payload shapes (API-65) ===

    @Test
    fun deviceCodeRequestSerializesItsClientId() {
        val text =
            kotlinx.serialization.json.Json.encodeToString(
                DeviceCodeRequest.serializer(),
                DeviceCodeRequest("karoo"),
            )
        assertEquals("""{"clientId":"karoo"}""", text)
    }
}
