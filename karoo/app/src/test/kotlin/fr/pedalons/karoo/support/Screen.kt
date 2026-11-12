package fr.pedalons.karoo.support

import fr.pedalons.karoo.support.Fixtures.entry
import fr.pedalons.karoo.support.Fixtures.ride
import fr.pedalons.karoo.support.Fixtures.route

/** Fixtures shared by the behaviour tests, with the English texts they produce. */
object Data {
    val threeRoutes =
        listOf(
            route("s1", "Solo loop", 30_000f, 300f),
            route("s2", "Lake tour", 50_000f, 450f),
            route("s3", "Hill climb", 20_000f, 1200f),
        )

    val twoEntryRide =
        ride(
            "ride-1",
            "Sunday ride",
            listOf(
                entry("r1", "Col de Porte", "Fast", 42_000f, 600f, start = "2026-11-14T08:30:00Z"),
                entry("r2", "Chartreuse", "Easy", 25_000f, 200f),
            ),
        )

    val singleEntryRide =
        ride(
            "ride-2",
            "Saturday spin",
            listOf(entry("r3", "Canal loop", null, 15_000f, 50f)),
            start = "2026-11-15T07:00:00Z",
        )
}
