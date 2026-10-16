using Toybox.WatchUi;
using Toybox.System;

/**
 * Input delegate for route detail view.
 */
class RouteDetailDelegate extends WatchUi.BehaviorDelegate {
    private var _view;
    private var _apiClient;
    private var _route;
    private var _isDownloading = false;

    function initialize(view, apiClient, route) {
        BehaviorDelegate.initialize();
        _view = view;
        _apiClient = apiClient;
        _route = route;
    }

    function onSelect() {
        if (_isDownloading) {
            return true; // Ignore while downloading
        }

        // Start download
        _isDownloading = true;
        _view.setDownloading(true);

        var teamSlug = _route.get("teamSlug");
        var routeSlug = _route.get("routeSlug");

        if (teamSlug != null && routeSlug != null) {
            if (!_apiClient.downloadRoute(teamSlug, routeSlug, method(:onDownloadComplete))) {
                _view.setDownloadBusy();
                _isDownloading = false;
            }
        } else {
            _view.setDownloadComplete(false);
            _isDownloading = false;
        }

        return true;
    }

    function onDownloadComplete(success) {
        _isDownloading = false;
        _view.setDownloadComplete(success);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
