using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;

/**
 * View displayed when an error occurs.
 */
class ErrorView extends WatchUi.View {
    private var _message;

    function initialize(message) {
        View.initialize();
        _message = message;
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        dc.setColor(Theme.text(), Theme.background());
        dc.clear();

        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        var layout = new VerticalLayout(centerY - 30, 8);

        layout.draw(dc, centerX, Graphics.FONT_SMALL, _message, null, Theme.danger());
        layout.draw(
            dc,
            centerX,
            Graphics.FONT_TINY,
            WatchUi.loadResource(Rez.Strings.Retry) + WatchUi.loadResource(Rez.Strings.SelectHint),
            null,
            Theme.muted()
        );
    }
}

/**
 * Input delegate for error view.
 */
class ErrorDelegate extends WatchUi.BehaviorDelegate {
    private var _app;

    function initialize(app) {
        BehaviorDelegate.initialize();
        _app = app;
    }

    function onSelect() {
        // Retry - go back to login or route list
        if (_app.getAuthManager().hasValidToken()) {
            var viewPair = _app.showRouteList();
            WatchUi.switchToView(viewPair[0], viewPair[1], WatchUi.SLIDE_IMMEDIATE);
        } else {
            var viewPair = _app.showLoginView();
            WatchUi.switchToView(viewPair[0], viewPair[1], WatchUi.SLIDE_IMMEDIATE);
        }
        return true;
    }

    function onBack() {
        // Exit app
        System.exit();
    }
}
