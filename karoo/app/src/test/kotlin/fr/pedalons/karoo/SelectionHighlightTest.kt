package fr.pedalons.karoo

import fr.pedalons.karoo.support.AppTestBase
import fr.pedalons.karoo.support.Data
import fr.pedalons.karoo.support.Fixtures
import fr.pedalons.karoo.support.ShadowKarooSystemService
import fr.pedalons.karoo.support.ok
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The selected row is only a highlight (no semantics), so it is observed on the rendered pixels of
 * the real activity after pressing the Karoo keys: it must move with Next / Previous on every list,
 * stop at the ends, and start on the first row of each new screen.
 */
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [ShadowKarooSystemService::class], qualifiers = "en-w256dp-h1200dp-300dpi")
class SelectionHighlightTest : AppTestBase() {

    private fun home() {
        backend.routes = {
            ok(
                Fixtures.routesJson(
                    rides = listOf(Data.twoEntryRide, Data.singleEntryRide),
                    routes = Data.threeRoutes,
                    groups =
                        listOf(
                            Fixtures.group("Fast"),
                            Fixtures.group("Easy"),
                            Fixtures.group("Slow"),
                        ),
                ),
            )
        }
        signIn()
        launch()
        waitForHome()
    }

    private val homeTitles = listOf("My next rides", "Rides", "Routes")
    private val routeTitles = listOf("Solo loop", "Lake tour", "Hill climb")
    private val rideTitles = listOf("Sunday ride", "Saturday spin")
    private val groupTitles = listOf("Fast", "Easy", "Slow")

    @Test
    fun home_highlightFollowsTheKeys() {
        home()
        assertSelectedRow(homeTitles, 0)
        next()
        assertSelectedRow(homeTitles, 1)
        next(5)
        assertSelectedRow(homeTitles, 2)
        previous()
        assertSelectedRow(homeTitles, 1)
    }

    @Test
    fun routeList_highlightFollowsTheKeys_andStartsOnTheFirstRow() {
        home()
        next(2)
        select()
        assertSelectedRow(routeTitles, 0)
        next()
        assertSelectedRow(routeTitles, 1)
        next(4)
        assertSelectedRow(routeTitles, 2)
        previous(5)
        assertSelectedRow(routeTitles, 0)

        next()
        back()
        next(2)
        select() // opened again: back on the first row
        assertSelectedRow(routeTitles, 0)
    }

    @Test
    fun rideList_highlightFollowsTheKeys() {
        home()
        next()
        select()
        assertSelectedRow(rideTitles, 0)
        next()
        assertSelectedRow(rideTitles, 1)
        next(3)
        assertSelectedRow(rideTitles, 1)
        previous()
        assertSelectedRow(rideTitles, 0)
    }

    @Test
    fun rideEntries_highlightFollowsTheKeys() {
        home()
        next()
        select()
        select() // the two-entry ride
        val entries = listOf("Fast", "Easy") // rows are the groups
        assertSelectedRow(entries, 0)
        next()
        assertSelectedRow(entries, 1)
        previous()
        assertSelectedRow(entries, 0)
    }

    @Test
    fun registeredGroupList_highlightFollowsTheKeys() {
        home()
        select()
        assertSelectedRow(groupTitles, 0)
        next()
        assertSelectedRow(groupTitles, 1)
        next(4)
        assertSelectedRow(groupTitles, 2)
        previous(2)
        assertSelectedRow(groupTitles, 0)
    }
}
