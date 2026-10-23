using Toybox.WatchUi;

/**
 * Input delegate for the "My next rides" Menu2: the groups the user is registered in.
 * Navigates to RouteDetailView for the selected group's route, like the Rides and Routes sections.
 */
class RegisteredGroupListMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _groups;
    private var _apiClient;

    function initialize(groups, apiClient) {
        Menu2InputDelegate.initialize();
        _groups = groups;
        _apiClient = apiClient;
    }

    function onSelect(item) {
        var index = item.getId();
        if (index != null && index < _groups.size()) {
            var group = _groups[index];
            var detailView = new RouteDetailView(group);
            var detailDelegate = new RouteDetailDelegate(detailView, _apiClient, group);
            WatchUi.pushView(detailView, detailDelegate, WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
