using Toybox.WatchUi;
using Toybox.Graphics;

/**
 * Main route list view.
 * Shows loading/error states, then switches to Home Menu when data is loaded.
 */
class PedalonsView extends WatchUi.View {
    private var _apiClient;
    private var _isLoading = true;
    private var _error;
    private var _formatUtils;

    function initialize(apiClient) {
        View.initialize();
        _apiClient = apiClient;
        _error = null;
        _formatUtils = new FormatUtils();
    }

    function onShow() {
        // Load routes when view is shown
        loadRoutes();
    }

    function loadRoutes() {
        _isLoading = true;
        _error = null;
        WatchUi.requestUpdate();

        _apiClient.fetchRoutes(method(:onRoutesLoaded));
    }

    function onRoutesLoaded(result) {
        _isLoading = false;

        if (result != null && result instanceof Toybox.Lang.Dictionary) {
            var rides = result.get("rides");
            var routes = result.get("routes");
            var groups = result.get("registeredGroups");

            if (rides == null) {
                rides = [];
            }
            if (routes == null) {
                routes = [];
            }
            if (groups == null) {
                groups = [];
            }

            if (rides.size() == 0 && routes.size() == 0 && groups.size() == 0) {
                _error = WatchUi.loadResource(Rez.Strings.NoRoutes);
                WatchUi.requestUpdate();
                return;
            }

            // Build Home Menu: My next rides, Rides, Routes, Logout
            var menu = new WatchUi.Menu2({
                :title => WatchUi.loadResource(Rez.Strings.RoutesTitle),
            });

            if (menu has :setActionMenuIndicator) {
                menu.setActionMenuIndicator({ :enabled => false });
            }
            if (menu has :setControlBar) {
                menu.setControlBar({
                    :leftButton => WatchUi.CONTROL_BAR_LEFT_BUTTON_BACK,
                });
            }

            // My next rides entry: the groups the user is registered in, always first
            var groupsSublabel =
                groups.size() + " " + WatchUi.loadResource(Rez.Strings.Registrations);
            if (groups.size() == 0) {
                groupsSublabel = WatchUi.loadResource(Rez.Strings.NoRegisteredGroups);
            }
            menu.addItem(
                new WatchUi.MenuItem(
                    WatchUi.loadResource(Rez.Strings.RegisteredGroups),
                    groupsSublabel,
                    "groups",
                    {}
                )
            );

            // Rides entry
            var ridesLabel = WatchUi.loadResource(Rez.Strings.Rides);
            var ridesSublabel = rides.size() + " " + ridesLabel.toLower();
            if (rides.size() == 0) {
                ridesSublabel = WatchUi.loadResource(Rez.Strings.NoRides);
            }
            var ridesItem = new WatchUi.MenuItem(ridesLabel, ridesSublabel, "rides", {});

            // Routes entry
            var routesLabel = WatchUi.loadResource(Rez.Strings.Routes);
            var routesSublabel = routes.size() + " " + routesLabel.toLower();
            if (routes.size() == 0) {
                routesSublabel = WatchUi.loadResource(Rez.Strings.NoRoutes);
            }
            var routesItem = new WatchUi.MenuItem(routesLabel, routesSublabel, "routes", {});

            // Put Routes first when there are no rides to show
            if (rides.size() == 0) {
                menu.addItem(routesItem);
                menu.addItem(ridesItem);
            } else {
                menu.addItem(ridesItem);
                menu.addItem(routesItem);
            }

            // Logout entry
            menu.addItem(
                new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Logout), null, "logout", {})
            );

            WatchUi.switchToView(
                menu,
                new HomeMenuDelegate(groups, rides, routes, _apiClient, _formatUtils),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else {
            _error = WatchUi.loadResource(Rez.Strings.ConnectionError);
            WatchUi.requestUpdate();
        }
    }

    function getApiClient() {
        return _apiClient;
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        // Clear screen
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2;

        if (_isLoading) {
            // Show loading message
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                centerX,
                centerY,
                Graphics.FONT_SMALL,
                WatchUi.loadResource(Rez.Strings.LoadingRoutes),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }

        if (_error != null) {
            // Show error
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                centerX,
                centerY,
                Graphics.FONT_SMALL,
                _error,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }
    }
}
