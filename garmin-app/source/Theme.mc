using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;

/**
 * Colours of everything the app draws — the menus (PdlMenu.mc) and the login, loading, route
 * detail and error views — light or dark like the Edge's day/night setting
 * (docs/BRANDING.md §1, light/dark parity). The values are the charter's (§3.2, §3.4): text and
 * surfaces, the indigo primary, and the soft badge pairs.
 *
 * Dark is the fallback: an Edge without the setting (before API 4.1.2 — 530, 830, 1030) is
 * always dark.
 */
module Theme {
    function isDark() as Lang.Boolean {
        var settings = System.getDeviceSettings();
        if (settings has :isNightModeEnabled) {
            return settings.isNightModeEnabled != false;
        }
        return true;
    }

    // Black, not the charter's #242424: the firmware's own title bar is black, and a 16-bit
    // Edge screen renders #242424 with a green cast.
    function background() as Lang.Number {
        return isDark() ? 0x000000 : 0xffffff;
    }

    function text() as Lang.Number {
        return isDark() ? 0xffffff : 0x000000;
    }

    // Secondary lines: hints, labels above a value
    function muted() as Lang.Number {
        return isDark() ? 0x9a9a9a : 0x666d75;
    }

    function divider() as Lang.Number {
        return isDark() ? 0x424242 : 0xdee2e6;
    }

    // The call to action and the waiting status: the charter's link colour
    function accent() as Lang.Number {
        return isDark() ? 0x91a7ff : 0x3b5bdb;
    }

    // Soft indigo: the day box, the highlighted row
    function soft() as Lang.Number {
        return isDark() ? 0x1b2864 : 0xdbe4ff;
    }

    function onSoft() as Lang.Number {
        return isDark() ? 0xedf2ff : 0x364fc7;
    }

    function success() as Lang.Number {
        return isDark() ? 0x40c057 : 0x2b8a3e;
    }

    function danger() as Lang.Number {
        return isDark() ? 0xfa5252 : 0xc92a2a;
    }

    // Work in progress (a download under way)
    function pending() as Lang.Number {
        return isDark() ? 0xfab005 : 0xd9480f;
    }

    // A soft badge pair [background, text] for a colour family (BRANDING.md §3.4, §7.4)
    function tone(family as Lang.Symbol) as Lang.Array<Lang.Number> {
        var dark = isDark();
        if (family == :green) {
            return dark ? [0x16451f, 0xebfbee] : [0xd3f9d8, 0x2b8a3e];
        } else if (family == :orange) {
            return dark ? [0x6d2408, 0xfff4e6] : [0xffe8cc, 0xd9480f];
        } else if (family == :red) {
            return dark ? [0x651515, 0xfff5f5] : [0xffe3e3, 0xc92a2a];
        } else if (family == :blue) {
            return dark ? [0x0c3256, 0xe7f5ff] : [0xd0ebff, 0x1864ab];
        } else if (family == :indigo) {
            return [soft(), onSoft()];
        }
        return dark ? [0x111315, 0xf8f9fa] : [0xf1f3f5, 0x212529];
    }
}
