package fr.pedalons.karoo

import fr.pedalons.karoo.support.AppTestBase
import fr.pedalons.karoo.support.Data
import fr.pedalons.karoo.support.Fixtures
import fr.pedalons.karoo.support.Reply
import fr.pedalons.karoo.support.ShadowKarooSystemService
import fr.pedalons.karoo.support.ok
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The real flows under the French locale and a 24h clock: texts, dates and counts as a French rider
 * sees them (the goldens only cover the screens rendered in isolation).
 */
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [ShadowKarooSystemService::class], qualifiers = "fr-w256dp-h1200dp-300dpi")
class FrenchFlowsTest : AppTestBase() {

    @Before
    fun frenchLocale() {
        Locale.setDefault(Locale.FRANCE) // AppTestBase froze en-US; it restores the original
    }

    private fun home(groups: List<String> = listOf(Fixtures.group("Fast", state = "OUTDATED"))) {
        backend.routes = {
            ok(
                Fixtures.routesJson(
                    listOf(Data.twoEntryRide),
                    Data.threeRoutes,
                    groups,
                ),
            )
        }
        signIn()
        launch()
        waitForText("Prochaines sorties")
    }

    @Test
    fun home_isInFrenchWithCounts() {
        home()
        assertShown(
            "Prochaines sorties",
            "1 inscription",
            "Sorties",
            "1 sortie",
            "Parcours",
            "3 parcours",
        )
        assertNotShown("My next rides")
    }

    @Test
    fun registeredRows_followTheSharedRulesInFrench() {
        home(
            groups =
                listOf(
                    Fixtures.group("B", distance = 92_400f, elevation = 1240f),
                    Fixtures.group("Fast", start = "2026-11-13T22:00:00Z")
                        .replace("Europe/Paris", "Asia/Tokyo"),
                ),
        )
        assertShown("2 inscriptions")
        select()
        assertShown(
            "Groupe B",
            "sam. 14 nov. · 09:30",
            "92,4\u00a0km",
            "1\u00a0240\u00a0m D+",
            "sam. 14 nov. · 07:00",
            "heure de Tokyo (ven. 23:00 chez vous)",
        )
    }

    @Test
    fun registeredRow_showsTheFrenchDateStatusAndSyncs() {
        home()
        select()
        // 08:30 UTC on 14 Nov 2026 is 09:30 in Paris; French short date, 24h time.
        assertShown("Fast", "Sunday ride", "sam. 14 nov. · 09:30", "Ancienne version sur le Karoo")

        select()
        waitForText("Parcours synchronisé !")
        assertEquals(1, backend.syncRequests().size)
        assertNotShown("Ancienne version sur le Karoo")
    }

    @Test
    fun registeredRow_failureIsInFrench() {
        backend.sync = { Reply(500, "boom") }
        home()
        select()
        select()
        waitForText("Échec de la synchronisation")
    }

    @Test
    fun routeDetail_syncShowsFrenchTextsAndTheStartDate() {
        home()
        next()
        select() // rides
        select() // the ride's groups
        assertShown("Sunday ride", "sam. 14 nov. · 09:30", "sam. 14 nov. · 09:00")
        select()
        assertShown("Sync vers Karoo")
        select()
        waitForText("Parcours synchronisé !")
    }
}
