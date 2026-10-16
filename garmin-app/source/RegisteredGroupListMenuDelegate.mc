using Toybox.WatchUi;

/**
 * Input delegate for the "My next rides" Menu2: the groups the user is registered in.
 * Selecting a group downloads its route straight away, with no route detail screen.
 */
class RegisteredGroupListMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _groups;
    private var _apiClient;
    private var _progress;
    private var _isDownloading = false;

    function initialize(groups, apiClient) {
        Menu2InputDelegate.initialize();
        _groups = groups;
        _apiClient = apiClient;
        _progress = null;
    }

    function onSelect(item) {
        var index = item.getId();
        if (_isDownloading || index == null || index >= _groups.size()) {
            return;
        }
        var group = _groups[index];
        var teamSlug = group.get("teamSlug");
        var routeSlug = group.get("routeSlug");
        if (teamSlug == null || routeSlug == null) {
            return;
        }

        _isDownloading = true;
        _progress = new WatchUi.ProgressBar(WatchUi.loadResource(Rez.Strings.Downloading), null);
        WatchUi.pushView(_progress, new DownloadProgressDelegate(self), WatchUi.SLIDE_LEFT);
        if (!_apiClient.downloadRoute(teamSlug, routeSlug, method(:onDownloadComplete))) {
            // Another download is still in flight: say so, nothing was started.
            _isDownloading = false;
            _progress.setProgress(0);
            _progress.setDisplayString(WatchUi.loadResource(Rez.Strings.DownloadBusy));
        }
    }

    function onDownloadComplete(success) {
        _isDownloading = false;
        if (_progress == null) {
            return; // Progress screen already dismissed
        }
        _progress.setProgress(success ? 100 : 0);
        _progress.setDisplayString(
            WatchUi.loadResource(
                success ? Rez.Strings.DownloadComplete : Rez.Strings.DownloadFailed
            )
        );
        WatchUi.requestUpdate();
    }

    /**
     * Called when the progress screen is dismissed: a late result is no longer displayed.
     */
    function onProgressDismissed() {
        _progress = null;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

/**
 * Input delegate for the download progress screen: back (or select) closes it.
 * The download itself carries on and still lands on the device.
 */
class DownloadProgressDelegate extends WatchUi.BehaviorDelegate {
    private var _owner;

    function initialize(owner) {
        BehaviorDelegate.initialize();
        _owner = owner;
    }

    function onBack() {
        _owner.onProgressDismissed();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onSelect() {
        return onBack();
    }
}
