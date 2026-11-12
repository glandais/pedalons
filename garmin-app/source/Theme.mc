using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;

/**
 * Colours of the views the app draws itself (login, loading, route detail, error), light or dark
 * like the Edge's day/night setting (docs/BRANDING.md §1, light/dark parity).
 *
 * The menus are not covered: they are Menu2, drawn by the firmware, and stay light in night mode
 * in the simulator. Menu2.setTheme is no way out: its themes are accent colours (blue, cyan…),
 * not light or dark.
 *
 * Dark is the fallback: an Edge without the setting (before API 4.1.2 — 530, 830, 1030) keeps the
 * black screens it always had. The colours are the firmware's named ones, which every Edge
 * palette renders as is; on white they are the darker of each pair, to stay readable in the sun.
 */
module Theme {
    function isDark() as Lang.Boolean {
        var settings = System.getDeviceSettings();
        if (settings has :isNightModeEnabled) {
            return settings.isNightModeEnabled != false;
        }
        return true;
    }

    function background() as Graphics.ColorType {
        return isDark() ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
    }

    function text() as Graphics.ColorType {
        return isDark() ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
    }

    // Secondary lines: hints, labels above a value
    function muted() as Graphics.ColorType {
        return isDark() ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY;
    }

    // The call to action and the waiting status
    function accent() as Graphics.ColorType {
        return isDark() ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_BLUE;
    }

    function success() as Graphics.ColorType {
        return isDark() ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GREEN;
    }

    function danger() as Graphics.ColorType {
        return isDark() ? Graphics.COLOR_RED : Graphics.COLOR_DK_RED;
    }

    // Work in progress (a download under way)
    function pending() as Graphics.ColorType {
        return isDark() ? Graphics.COLOR_YELLOW : Graphics.COLOR_ORANGE;
    }
}
