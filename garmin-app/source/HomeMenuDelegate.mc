using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System;

/**
 * Input delegate for the home Menu2.
 * Handles selection of "My next rides", "Rides" or "Routes" top-level entries.
 */
class HomeMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _groups;
    private var _rides;
    private var _routes;
    private var _apiClient;
    private var _formatUtils;

    function initialize(groups, rides, routes, apiClient, formatUtils) {
        Menu2InputDelegate.initialize();
        _groups = groups;
        _rides = rides;
        _routes = routes;
        _apiClient = apiClient;
        _formatUtils = formatUtils;
    }

    function onSelect(item) {
        var id = item.getId();

        if (id.equals("groups")) {
            if (_groups.size() == 0) {
                return; // Nothing to show
            }

            // Build the list of the groups the user is registered in
            var menu = new WatchUi.Menu2({
                :title => WatchUi.loadResource(Rez.Strings.RegisteredGroups),
            });
            if (menu has :setControlBar) {
                menu.setControlBar({
                    :leftButton => WatchUi.CONTROL_BAR_LEFT_BUTTON_BACK,
                });
            }

            for (var i = 0; i < _groups.size(); i++) {
                var group = _groups[i];
                var sublabel = _formatUtils.formatDateTime(group.get("startDateTime"));
                var groupName = group.get("groupName");
                if (groupName != null && groupName.length() > 0) {
                    sublabel = sublabel.length() > 0 ? sublabel + " " + groupName : groupName;
                }
                menu.addItem(new WatchUi.MenuItem(group.get("rideName"), sublabel, i, {}));
            }

            WatchUi.pushView(
                menu,
                new RegisteredGroupListMenuDelegate(_groups, _apiClient),
                WatchUi.SLIDE_LEFT
            );
        } else if (id.equals("rides")) {
            if (_rides.size() == 0) {
                return; // Nothing to show
            }

            // Build ride list menu
            var menu = new WatchUi.Menu2({
                :title => WatchUi.loadResource(Rez.Strings.Rides),
            });
            if (menu has :setControlBar) {
                menu.setControlBar({
                    :leftButton => WatchUi.CONTROL_BAR_LEFT_BUTTON_BACK,
                });
            }

            for (var i = 0; i < _rides.size(); i++) {
                var ride = _rides[i];
                var rideName = ride.get("rideName");
                var startDateTime = ride.get("startDateTime");
                var sublabel = "";
                if (startDateTime != null && startDateTime.length() > 0) {
                    sublabel = _formatUtils.formatDateTime(startDateTime);
                }
                var entries = ride.get("entries");
                var entryCount = entries != null ? entries.size() : 0;
                if (sublabel.length() > 0) {
                    sublabel = sublabel + " (" + entryCount + ")";
                } else {
                    sublabel = entryCount.toString();
                }
                menu.addItem(new WatchUi.MenuItem(rideName, sublabel, i, {}));
            }

            WatchUi.pushView(
                menu,
                new RideListMenuDelegate(_rides, _apiClient, _formatUtils),
                WatchUi.SLIDE_LEFT
            );
        } else if (id.equals("routes")) {
            if (_routes.size() == 0) {
                return; // Nothing to show
            }

            // Build standalone route list menu
            var menu = new WatchUi.Menu2({
                :title => WatchUi.loadResource(Rez.Strings.Routes),
            });
            if (menu has :setControlBar) {
                menu.setControlBar({
                    :leftButton => WatchUi.CONTROL_BAR_LEFT_BUTTON_BACK,
                });
            }

            for (var i = 0; i < _routes.size(); i++) {
                var route = _routes[i];
                var routeName = route.get("routeName");
                var distance = route.get("distance");
                var elevationGain = route.get("elevationGain");
                var sublabel = _formatUtils.formatDistanceElevation(distance, elevationGain);
                menu.addItem(new WatchUi.MenuItem(routeName, sublabel, i, {}));
            }

            WatchUi.pushView(
                menu,
                new StandaloneRouteMenuDelegate(_routes, _apiClient),
                WatchUi.SLIDE_LEFT
            );
        } else if (id.equals("logout")) {
            var app = Application.getApp();
            app.getAuthManager().clearTokens();

            var viewPair = app.showLoginView();
            WatchUi.switchToView(viewPair[0], viewPair[1], WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onBack() {
        System.exit();
    }
}
