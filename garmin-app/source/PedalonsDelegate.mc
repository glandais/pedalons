using Toybox.WatchUi;
using Toybox.System;

/**
 * Input delegate for the loading/error view.
 * Once routes are loaded, HomeMenuDelegate handles the navigation menus.
 */
class PedalonsDelegate extends WatchUi.BehaviorDelegate {
    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        // Retry loading routes if there was an error
        _view.loadRoutes();
        return true;
    }

    function onMenu() {
        // Show menu with refresh option
        var menu = new PdlMenu(WatchUi.loadResource(Rez.Strings.MenuTitle), {});
        menu.addItem(
            new PdlItem("refresh", WatchUi.loadResource(Rez.Strings.RefreshRoutes), null, {})
        );
        WatchUi.pushView(menu, new LoadingMenuDelegate(_view), WatchUi.SLIDE_UP);
        return true;
    }

    function onBack() {
        // Exit app
        System.exit();
    }
}

/**
 * Menu delegate for loading view menu.
 */
class LoadingMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _view;

    function initialize(view) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id.equals("refresh")) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _view.loadRoutes();
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
