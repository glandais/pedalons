using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System;

/**
 * Input delegate for the home menu.
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

            // The groups the user is registered in: the day, the ride, then the time and the
            // group, and where the route stands in Garmin Connect as a badge of its own.
            var menu = new PdlMenu(WatchUi.loadResource(Rez.Strings.RegisteredGroups), {
                :badges => true,
                :dayBox => true,
            });

            for (var i = 0; i < _groups.size(); i++) {
                var group = _groups[i];
                var parts = _formatUtils.dateParts(group.get("startDateTime"));
                var sublabel = parts != null ? parts[3] : "";
                var groupName = group.get("groupName");
                if (groupName != null && groupName.length() > 0) {
                    sublabel = sublabel.length() > 0 ? sublabel + " · " + groupName : groupName;
                }
                var options = { :day => parts };
                var sync = syncBadge(group.get("syncState"));
                if (sync != null) {
                    options.put(:badge, sync[0]);
                    options.put(:badgeFamily, sync[1]);
                }
                menu.addItem(new PdlItem(i, group.get("rideName"), sublabel, options));
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

            // Rides: the day, the name, then the time and how many groups
            var menu = new PdlMenu(WatchUi.loadResource(Rez.Strings.Rides), { :dayBox => true });

            for (var i = 0; i < _rides.size(); i++) {
                var ride = _rides[i];
                var parts = _formatUtils.dateParts(ride.get("startDateTime"));
                var entries = ride.get("entries");
                var entryCount = entries != null ? entries.size() : 0;
                var sublabel =
                    entryCount +
                    " " +
                    WatchUi.loadResource(
                        entryCount == 1 ? Rez.Strings.GroupOne : Rez.Strings.GroupMany
                    );
                if (parts != null) {
                    sublabel = parts[3] + " · " + sublabel;
                }
                menu.addItem(new PdlItem(i, ride.get("rideName"), sublabel, { :day => parts }));
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

            // Routes attached to no ride: the name, then distance and elevation
            var menu = new PdlMenu(WatchUi.loadResource(Rez.Strings.Routes), {});

            for (var i = 0; i < _routes.size(); i++) {
                var route = _routes[i];
                var sublabel = _formatUtils.formatDistanceElevation(
                    route.get("distance"),
                    route.get("elevationGain")
                );
                menu.addItem(new PdlItem(i, route.get("routeName"), sublabel, {}));
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

    /**
     * The badge for a group's route state in Garmin Connect (docs/LEDGER_*.md API-121), as
     * [text, colour family], or null when there is nothing to say: not held by Garmin, an older
     * backend, or an unknown state.
     */
    private function syncBadge(state) {
        if (state == null) {
            return null;
        } else if (state.equals("SENT")) {
            return [WatchUi.loadResource(Rez.Strings.SyncSent), :green];
        } else if (state.equals("OUTDATED")) {
            return [WatchUi.loadResource(Rez.Strings.SyncOutdated), :orange];
        } else if (state.equals("PENDING")) {
            return [WatchUi.loadResource(Rez.Strings.SyncPending), :gray];
        } else if (state.equals("FAILING")) {
            return [WatchUi.loadResource(Rez.Strings.SyncFailing), :red];
        } else if (state.equals("RECONNECT_REQUIRED")) {
            return [WatchUi.loadResource(Rez.Strings.SyncReconnect), :red];
        }
        return null;
    }

    function onBack() {
        System.exit();
    }
}
