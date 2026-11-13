using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

/**
 * The number formats of the app and the site (contracts/format-cases.json, docs/BRANDING.md
 * §8.3), as pure functions so FormatCasesTest can check them: « 92,4 km » and « 1 240 m » in
 * French, "92.4 km" and "1,240 m" in English, a no-break space before the unit.
 */
module Fmt {
    const KM_TO_MI = 0.621371;
    const M_TO_FT = 3.28084;
    const NBSP = "\u00A0";

    // One decimal, with the language's decimal separator
    function decimal(value, french) {
        var text = value.format("%.1f");
        if (french) {
            var dot = text.find(".");
            if (dot != null) {
                text = text.substring(0, dot) + "," + text.substring(dot + 1, text.length());
            }
        }
        return text;
    }

    // A whole number, thousands apart: a no-break space in French, a comma in English
    function grouped(value, french) {
        var digits = value.format("%.0f");
        var out = "";
        var n = digits.length();
        for (var i = 0; i < n; i++) {
            if (i > 0 && (n - i) % 3 == 0 && !digits.substring(i - 1, i).equals("-")) {
                out += french ? NBSP : ",";
            }
            out += digits.substring(i, i + 1);
        }
        return out;
    }

    function distance(meters, metric, french, unit) {
        var value = metric ? meters / 1000.0 : (meters / 1000.0) * KM_TO_MI;
        return decimal(value, french) + NBSP + unit;
    }

    function elevation(meters, metric, french, unit) {
        return grouped(metric ? meters : meters * M_TO_FT, french) + NBSP + unit;
    }
}

/**
 * Formats distances, elevations and departures from the Edge's settings: units, 12/24 h and
 * language. The language decides the separators and the order of a date — never the 12/24 h
 * setting, which once turned a French Edge set to 12 h to MM/DD (ledger API-159).
 */
class FormatUtils {
    private var _isMetricDistance;
    private var _isMetricElevation;
    private var _is24Hour;
    private var _french;

    function initialize() {
        var settings = System.getDeviceSettings();
        _isMetricDistance = settings.distanceUnits == System.UNIT_METRIC;
        _isMetricElevation = settings.elevationUnits == System.UNIT_METRIC;
        _is24Hour = settings.is24Hour;
        _french = settings.systemLanguage == System.LANGUAGE_FRE;
    }

    // "92.4 km", « 92,4 km », "57.4 mi"
    function formatDistance(meters) {
        if (meters == null) {
            return "";
        }
        return onScreen(
            Fmt.distance(
                meters,
                _isMetricDistance,
                _french,
                WatchUi.loadResource(_isMetricDistance ? Rez.Strings.UnitKm : Rez.Strings.UnitMi)
            )
        );
    }

    // "1,240 m", « 1 240 m », "4,068 ft"
    function formatElevation(meters) {
        if (meters == null) {
            return "";
        }
        return onScreen(
            Fmt.elevation(
                meters,
                _isMetricElevation,
                _french,
                WatchUi.loadResource(_isMetricElevation ? Rez.Strings.UnitM : Rez.Strings.UnitFt)
            )
        );
    }

    // The Edge fonts draw a no-break space twice as wide as a space (« 27,9  km », seen on the
    // Edge 1050): what goes to the screen gets plain spaces, and nothing wraps there anyway.
    private function onScreen(text) {
        var at = text.find(Fmt.NBSP);
        while (at != null) {
            text = text.substring(0, at) + " " + text.substring(at + 1, text.length());
            at = text.find(Fmt.NBSP);
        }
        return text;
    }

    // « 92,4 km · 1 240 m D+ »
    function formatDistanceElevation(distance, elevation) {
        var distStr = formatDistance(distance);
        var elevStr = "";
        if (elevation != null) {
            elevStr =
                formatElevation(elevation) + " " + WatchUi.loadResource(Rez.Strings.UnitDPlus);
        }
        if (distStr.length() > 0 && elevStr.length() > 0) {
            return distStr + " · " + elevStr;
        } else if (distStr.length() > 0) {
            return distStr;
        }
        return elevStr;
    }

    /**
     * A departure in the single format of the app (BRANDING.md §8.3): « sam. 14 nov. · 09:30 »,
     * "Sat, Nov 14 · 9:30 AM", with the year when it is not the current one. The weekday and the
     * month are the firmware's abbreviations, in the Edge's language; the time is the Edge's
     * local time, not the ride's own zone, which the device API does not give this app.
     */
    function formatDeparture(isoString) {
        if (isoString == null) {
            return "";
        }
        var moment = parseIsoDateTime(isoString);
        if (moment == null) {
            return "";
        }
        var info = Gregorian.info(moment, Time.FORMAT_MEDIUM);
        var day = _french
            ? weekday(info) + " " + info.day + " " + month(info)
            : weekday(info) + ", " + month(info) + " " + info.day;
        if (info.year != Gregorian.info(Time.now(), Time.FORMAT_SHORT).year) {
            day += (_french ? " " : ", ") + info.year;
        }
        return day + " · " + formatTime(info);
    }

    // The weekday and the hour, for a departure within the week: « sam. 09:30 », "Sat 9:30 AM"
    function formatWeekdayTime(isoString) {
        var parts = dateParts(isoString);
        return parts != null ? parts[0] + " " + parts[3] : "";
    }

    // The firmware's abbreviations, written as the app writes them in French: it gives « Sam »
    // and « Nov. », the app « sam. » and « nov. ». English is left as the firmware has it.
    private function weekday(info) {
        var text = info.day_of_week;
        if (!_french) {
            return text;
        }
        text = text.toLower();
        return text.find(".") == null ? text + "." : text;
    }

    private function month(info) {
        return _french ? info.month.toLower() : info.month;
    }

    // The hour of a departure alone, for « Départ 09:30 »: "09:30", "9:30 AM". Empty when unknown.
    function formatDepartureTime(isoString) {
        var parts = dateParts(isoString);
        return parts != null ? parts[3] : "";
    }

    // "09:30", or "9:30 AM" on a 12-hour Edge (no leading zero, as the app writes it)
    private function formatTime(info) {
        if (_is24Hour) {
            return info.hour.format("%02d") + ":" + info.min.format("%02d");
        }
        var hour = info.hour % 12;
        if (hour == 0) {
            hour = 12; // 0:xx and 12:xx both display as 12
        }
        var suffix = WatchUi.loadResource(info.hour >= 12 ? Rez.Strings.PM : Rez.Strings.AM);
        return hour + ":" + info.min.format("%02d") + " " + suffix;
    }

    /**
     * An ISO 8601 instant split for a menu row: [weekday, day, month, time], the weekday and
     * the month abbreviated in the Edge's language ("Sat", "14", "Nov", "08:45"). Null when the
     * string cannot be read.
     */
    function dateParts(isoString) {
        if (isoString == null) {
            return null;
        }
        var moment = parseIsoDateTime(isoString);
        if (moment == null) {
            return null;
        }
        var info = Gregorian.info(moment, Time.FORMAT_MEDIUM);
        return [weekday(info), info.day.toString(), month(info), formatTime(info)];
    }

    /**
     * Parse ISO 8601 datetime string to Moment.
     * Handles UTC timezone (Z suffix) and converts to local time.
     * Supports format: "2025-01-25T09:00:00Z"
     */
    private function parseIsoDateTime(isoString) {
        if (isoString == null || isoString.length() < 19) {
            return null;
        }

        // Extract components: 2025-01-25T09:00:00
        var year = isoString.substring(0, 4).toNumber();
        var month = isoString.substring(5, 7).toNumber();
        var day = isoString.substring(8, 10).toNumber();
        var hour = isoString.substring(11, 13).toNumber();
        var min = isoString.substring(14, 16).toNumber();
        var sec = isoString.substring(17, 19).toNumber();

        if (
            year == null ||
            month == null ||
            day == null ||
            hour == null ||
            min == null ||
            sec == null
        ) {
            return null;
        }

        // From documentation : Each option value is assumed to be in the UTC time zone.
        var options = {
            :year => year,
            :month => month,
            :day => day,
            :hour => hour,
            :minute => min,
            :second => sec,
        };
        return Gregorian.moment(options);
    }
}
