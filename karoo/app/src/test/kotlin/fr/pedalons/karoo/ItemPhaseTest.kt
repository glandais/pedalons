package fr.pedalons.karoo

import fr.pedalons.karoo.browse.ItemPhase
import fr.pedalons.karoo.browse.itemPhase
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The phase of a ride group or a trip stage, the rule of the app
 * (`mobile/lib/features/teams/domain/publication_timing.dart`, docs/LEDGER_*.md API-194).
 */
class ItemPhaseTest {

    private val now = Instant.parse("2026-11-11T12:00:00Z")

    private fun phase(start: String?, end: String? = null, status: String? = "PUBLISHED") =
        itemPhase(start, end, status, now)

    @Test
    fun beforeItsDeparture_isUpcoming() {
        assertEquals(ItemPhase.UPCOMING, phase("2026-11-11T12:00:01Z", "2026-11-11T15:00:00Z"))
    }

    @Test
    fun betweenDepartureAndArrival_isUnderWay() {
        assertEquals(ItemPhase.UNDER_WAY, phase("2026-11-11T10:00:00Z", "2026-11-11T12:00:01Z"))
        // The departure itself has happened.
        assertEquals(ItemPhase.UNDER_WAY, phase("2026-11-11T12:00:00Z", "2026-11-11T15:00:00Z"))
    }

    @Test
    fun fromItsArrival_isFinished() {
        assertEquals(ItemPhase.FINISHED, phase("2026-11-11T08:00:00Z", "2026-11-11T12:00:00Z"))
    }

    @Test
    fun withoutAnArrival_lastsThreeHours() {
        assertEquals(ItemPhase.UNDER_WAY, phase("2026-11-11T09:00:01Z"))
        assertEquals(ItemPhase.FINISHED, phase("2026-11-11T09:00:00Z"))
        assertEquals(ItemPhase.UNDER_WAY, phase("2026-11-11T09:00:01Z", "not a date"))
    }

    @Test
    fun cancelled_isNeverUnderWay() {
        assertEquals(
            ItemPhase.FINISHED,
            phase("2026-11-11T10:00:00Z", "2026-11-11T15:00:00Z", "CANCELLED"),
        )
        // Still to come until its departure: nothing to hide before.
        assertEquals(ItemPhase.UPCOMING, phase("2026-11-12T10:00:00Z", status = "CANCELLED"))
    }

    @Test
    fun anUnreadableStart_isUpcoming() {
        assertEquals(ItemPhase.UPCOMING, phase(null))
        assertEquals(ItemPhase.UPCOMING, phase("not a date"))
    }

    @Test
    fun anOlderServerWithoutStatus_isReadAsPublished() {
        assertEquals(ItemPhase.UNDER_WAY, phase("2026-11-11T10:00:00Z", status = null))
    }
}
