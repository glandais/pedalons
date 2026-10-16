using Toybox.WatchUi;
using Toybox.Graphics;

/**
 * Route detail view showing route information and download option.
 */
class RouteDetailView extends WatchUi.View {
    private var _route;
    private var _isDownloading = false;
    private var _downloadStatus;
    private var _formatUtils;

    function initialize(route) {
        View.initialize();
        if (View has :setActionMenuIndicator) {
            setActionMenuIndicator({ :enabled => false });
        }
        if (View has :setControlBar) {
            setControlBar({
                :leftButton => WatchUi.CONTROL_BAR_LEFT_BUTTON_BACK,
                :rightButton => WatchUi.CONTROL_BAR_RIGHT_BUTTON_ACCEPT,
                :title => WatchUi.loadResource(Rez.Strings.Download),
            });
        }
        _route = route;
        _downloadStatus = null;
        _formatUtils = new FormatUtils();
    }

    function setDownloading(downloading) {
        _isDownloading = downloading;
        if (downloading) {
            _downloadStatus = WatchUi.loadResource(Rez.Strings.Downloading);
        }
        WatchUi.requestUpdate();
    }

    function setDownloadComplete(success) {
        _isDownloading = false;
        if (success) {
            _downloadStatus = WatchUi.loadResource(Rez.Strings.DownloadComplete);
        } else {
            _downloadStatus = WatchUi.loadResource(Rez.Strings.DownloadFailed);
        }
        WatchUi.requestUpdate();
    }

    /** Another download is still in flight: nothing was started. */
    function setDownloadBusy() {
        _isDownloading = false;
        _downloadStatus = WatchUi.loadResource(Rez.Strings.DownloadBusy);
        WatchUi.requestUpdate();
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var centerX = dc.getWidth() / 2;
        var height = dc.getHeight();
        var layout = new VerticalLayout(10, 4);

        // Extract route data
        var routeName = _route.get("routeName");
        var rideName = _route.get("rideName");
        var startDateTime = _route.get("startDateTime");
        var groupName = _route.get("groupName");
        var distance = _route.get("distance");
        var elevationGain = _route.get("elevationGain");

        // 2. Ride name (if defined)
        if (rideName != null && rideName.length() > 0) {
            layout.draw(dc, centerX, Graphics.FONT_SMALL, rideName, null, Graphics.COLOR_WHITE);
        }

        // 3. Group name (if defined)
        if (groupName != null && groupName.length() > 0) {
            layout.draw(dc, centerX, Graphics.FONT_SMALL, groupName, null, Graphics.COLOR_LT_GRAY);
        }

        // 1. Route name (always shown)
        var displayRouteName =
            routeName != null && routeName.length() > 0
                ? routeName
                : WatchUi.loadResource(Rez.Strings.Unknown);
        layout.draw(
            dc,
            centerX,
            Graphics.FONT_SMALL,
            displayRouteName,
            null,
            Graphics.COLOR_LT_GRAY
        );

        // 4. Date/time (if Ride exists)
        if (startDateTime != null && startDateTime.length() > 0) {
            var dateStr = _formatUtils.formatDateTime(startDateTime);
            if (dateStr.length() > 0) {
                layout.draw(dc, centerX, Graphics.FONT_TINY, dateStr, null, Graphics.COLOR_WHITE);
            }
        }

        // 5. Distance & Elevation
        if (distance != null) {
            layout.draw(
                dc,
                centerX,
                Graphics.FONT_TINY,
                WatchUi.loadResource(Rez.Strings.Distance) +
                    ": " +
                    _formatUtils.formatDistance(distance),
                null,
                Graphics.COLOR_WHITE
            );
        }
        if (elevationGain != null) {
            layout.draw(
                dc,
                centerX,
                Graphics.FONT_TINY,
                WatchUi.loadResource(Rez.Strings.Elevation) +
                    ": " +
                    _formatUtils.formatElevation(elevationGain),
                null,
                Graphics.COLOR_WHITE
            );
        }

        // Download status at bottom
        drawDownloadStatus(dc, centerX, height - 60);
    }

    private function drawDownloadStatus(dc, centerX, y) {
        if (_isDownloading) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                centerX,
                y,
                Graphics.FONT_SMALL,
                _downloadStatus != null ? _downloadStatus : "...",
                Graphics.TEXT_JUSTIFY_CENTER
            );
        } else if (_downloadStatus != null) {
            var color = _downloadStatus.equals(WatchUi.loadResource(Rez.Strings.DownloadComplete))
                ? Graphics.COLOR_GREEN
                : Graphics.COLOR_RED;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                centerX,
                y,
                Graphics.FONT_SMALL,
                _downloadStatus,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        } else {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                centerX,
                y,
                Graphics.FONT_SMALL,
                WatchUi.loadResource(Rez.Strings.Download),
                Graphics.TEXT_JUSTIFY_CENTER
            );
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                centerX,
                y + 25,
                Graphics.FONT_TINY,
                WatchUi.loadResource(Rez.Strings.PressSelect),
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
    }
}
