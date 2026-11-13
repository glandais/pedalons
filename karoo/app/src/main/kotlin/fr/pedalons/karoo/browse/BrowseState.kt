package fr.pedalons.karoo.browse

import fr.pedalons.karoo.api.DeviceRide
import fr.pedalons.karoo.api.DeviceRideEntry
import fr.pedalons.karoo.api.DeviceRoute
import fr.pedalons.karoo.api.RegisteredItem
import fr.pedalons.karoo.api.RoutesResponse

/** What a transition asks the caller to do besides showing the new state. */
internal sealed interface BrowseOutcome {
    data object None : BrowseOutcome

    /** Back at the root: close the app. */
    data object Finish : BrowseOutcome

    /** Run the sync of a route; its result goes to [BrowseState.syncFinished] with [generation]. */
    data class StartSync(val teamSlug: String, val routeSlug: String, val generation: Int) :
        BrowseOutcome
}

internal data class BrowseStep(
    val state: BrowseState,
    val outcome: BrowseOutcome = BrowseOutcome.None,
)

/**
 * Everything the rider browses: the loaded routes, where they are in them, the selected row and the
 * sync feedback. Immutable and free of Android: every transition returns the next state (and what
 * to do about it), so the key and touch rules are plain-JVM testable.
 */
internal data class BrowseState(
    val response: RoutesResponse? = null,
    val current: NavState = NavState.Home,
    val stack: List<NavState> = emptyList(),
    val selectedIndex: Int = 0,
    val sync: SyncState = SyncState.IDLE,
    // Which row of the registered groups list [sync] is about (null elsewhere).
    val syncTargetIndex: Int? = null,
    // Bumped by every sync and every navigation: a sync only writes its result while it is still
    // the current one, so one left running behind a Back press cannot mark another row.
    val syncGeneration: Int = 0,
    // The routes ("teamSlug/routeSlug") synced from this Karoo since [response] was loaded: the
    // server's Hammerhead state in that response predates them, so the registered groups list
    // shows them as on the Karoo rather than the stale state (docs/LEDGER_*.md API-121). Reset
    // with every new response, whose states then supersede it.
    val syncedRoutes: Set<String> = emptySet(),
) {

    /** The rows of the current screen (0 for the detail, which has none). */
    val itemCount: Int
        get() =
            when (val state = current) {
                is NavState.Home -> response?.let { homeEntries(it).size } ?: 0
                is NavState.RegisteredGroupList -> state.items.size
                is NavState.RideList -> state.rides.size
                is NavState.RideEntries -> state.ride.entries.size
                is NavState.RouteList -> state.routes.size
                is NavState.RouteDetail -> 0
            }

    // === Hardware keys ===

    fun move(delta: Int): BrowseState =
        copy(selectedIndex = (selectedIndex + delta).coerceIn(0, (itemCount - 1).coerceAtLeast(0)))

    fun back(): BrowseStep =
        if (stack.isNotEmpty()) {
            BrowseStep(
                copy(
                    current = stack.last(),
                    stack = stack.dropLast(1),
                    selectedIndex = 0,
                    sync = SyncState.IDLE,
                    syncTargetIndex = null,
                    syncGeneration = syncGeneration + 1,
                ),
            )
        } else {
            BrowseStep(this, BrowseOutcome.Finish)
        }

    /** The key press on the selected row; an empty or out-of-range selection does nothing. */
    fun select(): BrowseStep =
        when (val state = current) {
            is NavState.Home ->
                response
                    ?.let { homeEntries(it).getOrNull(selectedIndex) }
                    ?.let { openHomeEntry(it) } ?: BrowseStep(this)
            is NavState.RegisteredGroupList ->
                state.items.getOrNull(selectedIndex)?.let { syncRegistered(it, selectedIndex) }
                    ?: BrowseStep(this)
            is NavState.RideList ->
                state.rides.getOrNull(selectedIndex)?.let { openRide(it) } ?: BrowseStep(this)
            is NavState.RideEntries ->
                state.ride.entries.getOrNull(selectedIndex)?.let { openRideEntry(state.ride, it) }
                    ?: BrowseStep(this)
            is NavState.RouteList ->
                state.routes.getOrNull(selectedIndex)?.let { openRoute(it) } ?: BrowseStep(this)
            is NavState.RouteDetail -> sync(state.teamSlug, state.routeSlug, null)
        }

    // === Touch: the touched item, the selection never moves ===

    fun openHomeEntry(entry: HomeEntry): BrowseStep {
        val response = response ?: return BrowseStep(this)
        return BrowseStep(
            navigateTo(
                when (entry) {
                    HomeEntry.REGISTERED -> NavState.RegisteredGroupList(response.registeredItems())
                    HomeEntry.RIDES -> NavState.RideList(response.rides)
                    HomeEntry.ROUTES -> NavState.RouteList(response.routes)
                },
            ),
        )
    }

    fun openRide(ride: DeviceRide): BrowseStep = BrowseStep(navigateTo(ride.openTarget()))

    fun openRideEntry(ride: DeviceRide, entry: DeviceRideEntry): BrowseStep =
        BrowseStep(navigateTo(NavState.RouteDetail.of(ride, entry)))

    fun openRoute(route: DeviceRoute): BrowseStep =
        BrowseStep(navigateTo(NavState.RouteDetail.of(route)))

    /**
     * The key or the touch on a row of « My next rides »: syncs its route — unless the ride or the
     * trip is cancelled, whose row has no control (KIT §9, docs/LEDGER_*.md API-194).
     */
    fun syncRegistered(item: RegisteredItem, row: Int): BrowseStep =
        if (item.isCancelled) BrowseStep(this) else sync(item.teamSlug, item.routeSlug, row)

    /**
     * Syncs a route to Hammerhead, the one action shared by the route detail screen and the
     * registered groups list ([row] is the row of that list, null from the detail screen). One sync
     * at a time, on any row or screen.
     */
    fun sync(teamSlug: String, routeSlug: String, row: Int?): BrowseStep {
        if (sync == SyncState.SYNCING) return BrowseStep(this)
        val generation = syncGeneration + 1
        return BrowseStep(
            copy(syncGeneration = generation, syncTargetIndex = row, sync = SyncState.SYNCING),
            BrowseOutcome.StartSync(teamSlug, routeSlug, generation),
        )
    }

    // === Async results ===

    /**
     * Keyed by route, not by row: a success is recorded even when the rider has moved on, since the
     * route did reach the Karoo whichever screen is shown now. The feedback itself only shows while
     * the sync is still the current one.
     */
    fun syncFinished(
        generation: Int,
        teamSlug: String,
        routeSlug: String,
        result: SyncState,
    ): BrowseState =
        copy(
            syncedRoutes =
                if (result == SyncState.SUCCESS) syncedRoutes + routeKey(teamSlug, routeSlug)
                else syncedRoutes,
            sync = if (generation == syncGeneration) result else sync,
        )

    /** A response with other content supersedes what was synced since the previous one. */
    fun withResponse(new: RoutesResponse?): BrowseState =
        copy(response = new, syncedRoutes = if (new != response) emptySet() else syncedRoutes)

    /** Back to the home screen; the selection stays when already there. Sync fields untouched. */
    fun resetToHome(): BrowseState =
        copy(
            current = NavState.Home,
            stack = emptyList(),
            selectedIndex = if (current == NavState.Home) selectedIndex else 0,
        )

    fun signedOut(): BrowseState = withResponse(null).resetToHome()

    private fun navigateTo(target: NavState): BrowseState =
        copy(
            current = target,
            stack = stack + current,
            selectedIndex = 0,
            sync = SyncState.IDLE,
            syncTargetIndex = null,
            syncGeneration = syncGeneration + 1,
        )
}
