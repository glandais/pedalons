using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

/**
 * The app's menus, drawn by the app (CustomMenu) rather than by the firmware (Menu2): Menu2 has
 * no light/dark theme on Edge and shows two lines of plain text, which is how a date, a sync
 * state and a group name ended up glued in one cut sublabel. Design: the « Pédalons Edge — menus
 * CustomMenu » canvas, after docs/BRANDING.md (day box §7.8, soft badges §7.4).
 *
 * Every size derives from the screen width and the system font heights, so one layout serves the
 * 246 px Edge 530 and the 480 px Edge 1050.
 *
 * Known limit: a menu's background colour is fixed when it opens. If the Edge changes between
 * day and night while a menu is on screen, its rows follow at once but the empty area under
 * them keeps the old colour until the menu is opened again.
 */
module Pdl {
    const LABEL_FONT = Graphics.FONT_SMALL;
    const SUB_FONT = Graphics.FONT_TINY;
    const SMALL_FONT = Graphics.FONT_XTINY;

    function pad() as Lang.Number {
        return System.getDeviceSettings().screenWidth / 24;
    }

    function badgeHeight() as Lang.Number {
        return Graphics.getFontHeight(SMALL_FONT) + 4;
    }

    // Height of the day box: weekday, day number, month
    function dayBoxHeight() as Lang.Number {
        return 2 * Graphics.getFontHeight(SMALL_FONT) + Graphics.getFontHeight(LABEL_FONT);
    }

    // Row height for a menu: label and sublabel, a badge line when the menu has badges, and
    // never less than the day box when its rows carry one.
    function rowHeight(withBadge as Lang.Boolean, withDayBox as Lang.Boolean) as Lang.Number {
        var h = Graphics.getFontHeight(LABEL_FONT) + Graphics.getFontHeight(SUB_FONT);
        if (withBadge) {
            h += badgeHeight() + pad() / 3;
        }
        if (withDayBox && h < dayBoxHeight()) {
            h = dayBoxHeight();
        }
        h += 2 * pad();
        // Always even: the focused row is one pixel taller, which is how it knows (PdlItem.draw)
        return h + (h % 2);
    }

    // `text` cut with an ellipsis to fit `width` pixels in `font`
    function fit(
        dc as Graphics.Dc,
        text as Lang.String,
        font,
        width as Lang.Number
    ) as Lang.String {
        if (dc.getTextWidthInPixels(text, font) <= width) {
            return text;
        }
        var n = text.length();
        while (n > 1) {
            n--;
            var cut = text.substring(0, n) + "…";
            if (dc.getTextWidthInPixels(cut, font) <= width) {
                return cut;
            }
        }
        return "";
    }
}

class PdlMenu extends WatchUi.CustomMenu {
    private var _title;
    private var _count = 0;
    private var _lastFocus = 0;

    // options: :badges (rows may carry a badge), :dayBox (rows carry a day box), :home (the
    // home menu, whose title is the app's name)
    function initialize(title, options) {
        // An Edge with a control bar already shows the app's name in it: the home menu, whose
        // title is that same name, then goes without a title of its own.
        var bare = options.get(:home) == true && WatchUi.Menu2 has :setControlBar;
        var rowHeight = Pdl.rowHeight(options.get(:badges) == true, options.get(:dayBox) == true);
        CustomMenu.initialize(rowHeight, Theme.background(), {
            :focusItemHeight => rowHeight + 1,
            :titleItemHeight => bare ? 1 : Graphics.getFontHeight(Graphics.FONT_MEDIUM) + Pdl.pad(),
        });
        _title = bare ? null : title;
        if (self has :setControlBar) {
            setControlBar({ :leftButton => WatchUi.CONTROL_BAR_LEFT_BUTTON_BACK });
        }
    }

    // Each row is told its menu and its rank, so the menu can remember which row had the focus
    // last (see lastFocus).
    function addItem(item) {
        (item as PdlItem).attach(weak(), _count);
        _count++;
        CustomMenu.addItem(item);
    }

    // The rank of the row that last reported the focus, the first row until one does. A menu
    // just opened, or shown again after a sub-menu, has its focus on a row that does not report
    // it before the focus moves: that row is lit from this memory.
    function lastFocus() {
        return _lastFocus;
    }

    function setLastFocus(rank) {
        if (_lastFocus != rank) {
            _lastFocus = rank;
            // The row lit from memory was drawn before this one: draw again without it
            WatchUi.requestUpdate();
        }
    }

    function drawTitle(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Theme.background(), Theme.background());
        dc.clear();
        if (_title == null) {
            return;
        }
        dc.setColor(Theme.text(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            h / 2,
            Graphics.FONT_MEDIUM,
            Pdl.fit(dc, _title, Graphics.FONT_MEDIUM, w - 4 * Pdl.pad()),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.setColor(Theme.divider(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(0, h - 1, w, h - 1);
        dc.setPenWidth(1);
    }
}

class PdlItem extends WatchUi.CustomMenuItem {
    private var _label;
    private var _sublabel;
    private var _day;
    private var _icon;
    private var _iconFamily;
    private var _badge;
    private var _badgeFamily;
    private var _dim;
    private var _menu = null;
    private var _rank = 0;
    // Texts cut to the row's width, at the first draw
    private var _fitWidth;
    private var _fitLabel;
    private var _fitSublabel;

    /**
     * options, all optional:
     *   :day => [weekday, day, month]   a day box on the left (FormatUtils.dateParts)
     *   :icon => :mine|:rides|:routes, :iconFamily => :indigo|:blue   a disc with a pictogram
     *   :badge => text, :badgeFamily => :green|:orange|:red|:gray     a soft badge under the texts
     *   :dim => true                    a secondary entry (logout)
     */
    function initialize(id, label, sublabel, options) {
        CustomMenuItem.initialize(id, {});
        _label = label != null ? label : "";
        _sublabel = sublabel != null ? sublabel : "";
        _day = options.get(:day);
        _icon = options.get(:icon);
        _iconFamily = options.get(:iconFamily);
        _badge = options.get(:badge);
        _badgeFamily = options.get(:badgeFamily);
        _dim = options.get(:dim) == true;
        _fitWidth = -1;
    }

    // Called by PdlMenu.addItem
    function attach(menu, rank) {
        _menu = menu;
        _rank = rank;
    }

    function draw(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var pad = Pdl.pad();
        // A row is lit while pressed, and when it has the focus on an Edge driven by buttons;
        // a touch screen has no focus to show.
        // isFocused() never answers true on API 3.3 (Edge 530, in the simulator at least), where
        // the focus does move: the focused row is also the one drawn one pixel taller, at an odd
        // height (PdlMenu sets :focusItemHeight to the even row height plus one).
        var focused = isFocused() || h % 2 == 1;
        var menu = _menu != null ? _menu.get() : null;
        if (menu != null) {
            if (focused) {
                menu.setLastFocus(_rank);
            } else {
                focused = menu.lastFocus() == _rank;
            }
        }
        var lit = isSelected() || (focused && !System.getDeviceSettings().isTouchScreen);

        dc.setColor(lit ? Theme.soft() : Theme.background(), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h);

        var x = pad;
        if (_day != null) {
            x += drawDayBox(dc, x, h, lit) + pad;
        } else if (_icon != null) {
            x += drawDisc(dc, x, h, lit) + pad;
        }

        var room = w - x - pad;
        if (_fitWidth != room) {
            _fitWidth = room;
            _fitLabel = Pdl.fit(dc, _label, Pdl.LABEL_FONT, room);
            _fitSublabel = Pdl.fit(dc, _sublabel, Pdl.SUB_FONT, room);
        }

        var labelH = dc.getFontHeight(Pdl.LABEL_FONT);
        var subH = _sublabel.length() > 0 ? dc.getFontHeight(Pdl.SUB_FONT) : 0;
        var badgeH = _badge != null ? Pdl.badgeHeight() + pad / 3 : 0;
        var y = (h - labelH - subH - badgeH) / 2;

        dc.setColor(_dim ? Theme.muted() : Theme.text(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Pdl.LABEL_FONT, _fitLabel, Graphics.TEXT_JUSTIFY_LEFT);
        y += labelH;
        if (subH > 0) {
            dc.setColor(lit ? Theme.onSoft() : Theme.muted(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, Pdl.SUB_FONT, _fitSublabel, Graphics.TEXT_JUSTIFY_LEFT);
            y += subH;
        }
        if (_badge != null) {
            drawBadge(dc, x, y + pad / 3, room);
        }

        dc.setColor(Theme.divider(), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, h - 1, w, h - 1);
    }

    // Weekday, day number and month on soft indigo (BRANDING.md §7.8). Returns its width.
    private function drawDayBox(dc, x, h, lit) {
        var smallH = dc.getFontHeight(Pdl.SMALL_FONT);
        var numH = dc.getFontHeight(Pdl.LABEL_FONT);
        var boxH = 2 * smallH + numH;
        var boxW = dc.getTextWidthInPixels("00000", Pdl.SMALL_FONT) + Pdl.pad();
        var top = (h - boxH) / 2;
        var cx = x + boxW / 2;
        dc.setColor(lit ? Theme.background() : Theme.soft(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, top, boxW, boxH, Pdl.pad() / 2);
        dc.setColor(Theme.onSoft(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top, Pdl.SMALL_FONT, _day[0], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.text(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top + smallH, Pdl.LABEL_FONT, _day[1], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.muted(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top + smallH + numH, Pdl.SMALL_FONT, _day[2], Graphics.TEXT_JUSTIFY_CENTER);
        return boxW;
    }

    // A soft disc with a line pictogram (calendar, calendar with a tick, route). Returns its width.
    private function drawDisc(dc, x, h, lit) {
        var d = dc.getFontHeight(Pdl.LABEL_FONT) + dc.getFontHeight(Pdl.SUB_FONT);
        var r = d / 2;
        var cx = x + r;
        var cy = h / 2;
        var tone = Theme.tone(_iconFamily != null ? _iconFamily : :indigo);
        dc.setColor(lit ? Theme.background() : tone[0], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(tone[1], Graphics.COLOR_TRANSPARENT);
        var s = (r * 11) / 10; // side of the pictogram
        var pen = s >= 24 ? 3 : 2;
        dc.setPenWidth(pen);
        if (_icon == :routes) {
            var a = s / 3;
            dc.drawLine(cx - a, cy + a, cx + a / 2, cy + a);
            dc.drawLine(cx + a / 2, cy + a, cx - a / 2, cy - a);
            dc.drawLine(cx - a / 2, cy - a, cx + a, cy - a);
            dc.fillCircle(cx - a, cy + a, pen + 1);
            dc.fillCircle(cx + a, cy - a, pen + 1);
        } else {
            var left = cx - s / 2;
            var top = cy - s / 2 + s / 8;
            dc.drawRoundedRectangle(left, top, s, s - s / 8, 3);
            dc.drawLine(left, top + s / 4, left + s, top + s / 4);
            dc.drawLine(cx - s / 4, top - s / 8, cx - s / 4, top + s / 10);
            dc.drawLine(cx + s / 4, top - s / 8, cx + s / 4, top + s / 10);
            if (_icon == :mine) {
                var ty = top + (s * 5) / 8;
                dc.drawLine(cx - s / 5, ty, cx - s / 20, ty + s / 6);
                dc.drawLine(cx - s / 20, ty + s / 6, cx + s / 4, ty - s / 8);
            }
        }
        dc.setPenWidth(1);
        return d;
    }

    private function drawBadge(dc, x, y, room) {
        var tone = Theme.tone(_badgeFamily != null ? _badgeFamily : :gray);
        var bh = Pdl.badgeHeight();
        var inner = bh / 2;
        var text = Pdl.fit(dc, _badge, Pdl.SMALL_FONT, room - 2 * inner);
        var bw = dc.getTextWidthInPixels(text, Pdl.SMALL_FONT) + 2 * inner;
        dc.setColor(tone[0], Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, bw, bh, bh / 2);
        dc.setColor(tone[1], Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + inner,
            y + bh / 2,
            Pdl.SMALL_FONT,
            text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
