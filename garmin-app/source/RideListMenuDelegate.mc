using Toybox.WatchUi;

/**
 * Input delegate for the ride list Menu2.
 * Navigates to ride entries or directly to RouteDetail if single entry.
 */
class RideListMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _rides;
    private var _apiClient;
    private var _formatUtils;

    function initialize(rides, apiClient, formatUtils) {
        Menu2InputDelegate.initialize();
        _rides = rides;
        _apiClient = apiClient;
        _formatUtils = formatUtils;
    }

    function onSelect(item) {
        var index = item.getId();
        if (index != null && index < _rides.size()) {
            var ride = _rides[index];
            var entries = ride.get("entries");

            if (entries == null || entries.size() == 0) {
                return;
            }

            // Bonus: if single entry, navigate directly to detail
            if (entries.size() == 1) {
                var entry = entries[0];
                var routeDict = buildRouteDict(ride, entry);
                var detailView = new RouteDetailView(routeDict);
                var detailDelegate = new RouteDetailDelegate(detailView, _apiClient, routeDict);
                WatchUi.pushView(detailView, detailDelegate, WatchUi.SLIDE_LEFT);
                return;
            }

            // Build entries menu
            var rideName = ride.get("rideName");
            var menu = new PdlMenu(
                rideName != null ? rideName : WatchUi.loadResource(Rez.Strings.Rides),
                {}
            );

            for (var i = 0; i < entries.size(); i++) {
                var entry = entries[i];
                var groupName = entry.get("groupName");
                var routeName = entry.get("routeName");
                var title = groupName != null && groupName.length() > 0 ? groupName : routeName;
                var distance = entry.get("distance");
                var elevationGain = entry.get("elevationGain");
                var sublabel = _formatUtils.formatDistanceElevation(distance, elevationGain);
                menu.addItem(new PdlItem(i, title, sublabel, {}));
            }

            WatchUi.pushView(menu, new RideEntryMenuDelegate(ride, _apiClient), WatchUi.SLIDE_LEFT);
        }
    }

    /**
     * Build a route dictionary suitable for RouteDetailView from ride + entry.
     */
    private function buildRouteDict(ride, entry) {
        return {
            "teamSlug" => ride.get("teamSlug"),
            "routeSlug" => entry.get("routeSlug"),
            "routeName" => entry.get("routeName"),
            "rideName" => ride.get("rideName"),
            "groupName" => entry.get("groupName"),
            "startDateTime" => entry.get("startDateTime"),
            "distance" => entry.get("distance"),
            "elevationGain" => entry.get("elevationGain"),
            "startLat" => entry.get("startLat"),
            "startLon" => entry.get("startLon"),
        };
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
