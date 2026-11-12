package fr.pedalons.karoo.support

/** JSON payloads in the shape the Pédalons backend sends them. */
object Fixtures {

    fun tokenJson(
        access: String = "access-1",
        refresh: String? = "refresh-1",
        expiresIn: Int = 3600,
    ) = buildString {
        append("""{"accessToken":"$access","tokenType":"Bearer","expiresIn":$expiresIn""")
        if (refresh != null) append(""","refreshToken":"$refresh"""")
        append("}")
    }

    fun deviceCodeJson(
        deviceCode: String = "device-code-1",
        userCode: String = "ABC123",
        uri: String = "https://www.pedalons.fr/karoo?code=ABC123",
        expiresIn: Int = 600,
        interval: Int = 1,
    ) =
        """{"deviceCode":"$deviceCode","userCode":"$userCode","verificationUri":"https://www.pedalons.fr/karoo",
           "verificationUriComplete":"$uri","expiresIn":$expiresIn,"interval":$interval}"""

    fun entry(
        slug: String,
        name: String,
        group: String? = null,
        distance: Float = 42_000f,
        elevation: Float = 600f,
        start: String? = null,
    ) = buildString {
        append("""{"routeSlug":"$slug","routeName":"$name",""")
        if (group != null) append(""""groupName":"$group",""")
        if (start != null) append(""""startDateTime":"$start",""")
        append(""""distance":$distance,"elevationGain":$elevation}""")
    }

    fun ride(
        slug: String,
        name: String,
        entries: List<String>,
        start: String? = "2026-11-14T08:00:00Z",
        team: String = "team-a",
    ) = buildString {
        append("""{"teamSlug":"$team","rideSlug":"$slug","rideName":"$name",""")
        if (start != null) append(""""startDateTime":"$start",""")
        append(""""entries":[${entries.joinToString(",")}]}""")
    }

    fun route(
        slug: String,
        name: String,
        distance: Float = 30_000f,
        elevation: Float = 300f,
        team: String = "team-a",
    ) =
        """{"teamSlug":"$team","routeSlug":"$slug","routeName":"$name","distance":$distance,"elevationGain":$elevation}"""

    /**
     * [states]: the Hammerhead state, null for `syncStatuses` absent, "" for no Hammerhead entry.
     */
    fun group(
        group: String,
        rideName: String = "Sunday ride",
        routeSlug: String = "route-$group",
        routeName: String = "Route $group",
        team: String = "team-a",
        start: String = "2026-11-14T08:30:00Z",
        state: String? = null,
        distance: Float = 42_000f,
        elevation: Float = 600f,
    ) = buildString {
        append(
            """{"teamSlug":"$team","rideSlug":"ride-$group","rideName":"$rideName","groupName":"$group",
               "routeSlug":"$routeSlug","routeName":"$routeName","distance":$distance,"elevationGain":$elevation,
               "startDateTime":"$start","timezone":"Europe/Paris"""",
        )
        when (state) {
            null -> {}
            "" -> append(""","syncStatuses":[]""")
            else -> append(""","syncStatuses":[{"serviceType":"HAMMERHEAD","state":"$state"}]""")
        }
        append("}")
    }

    fun routesJson(
        rides: List<String> =
            listOf(
                ride(
                    "ride-1",
                    "Sunday ride",
                    listOf(
                        entry("r1", "Col de Porte", "Fast", start = "2026-11-14T08:30:00Z"),
                        entry("r2", "Chartreuse", "Easy"),
                    ),
                ),
            ),
        routes: List<String> = listOf(route("s1", "Solo loop")),
        groups: List<String>? = listOf(group("Fast"), group("Easy")),
    ) = buildString {
        append("""{"rides":[${rides.joinToString(",")}],"routes":[${routes.joinToString(",")}]""")
        if (groups != null) append(""","registeredGroups":[${groups.joinToString(",")}]""")
        append("}")
    }
}
