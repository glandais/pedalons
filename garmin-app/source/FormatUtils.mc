using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

/**
 * Utility class for formatting distance, elevation, time, and date
 * based on device settings (metric/imperial, 12h/24h).
 */
class FormatUtils {
    // Conversion constants
    private static const KM_TO_MI = 0.621371;
    private static const M_TO_FT = 3.28084;

    private var _isMetricDistance;
    private var _isMetricElevation;
    private var _is24Hour;

    function initialize() {
        var settings = System.getDeviceSettings();
        _isMetricDistance = settings.distanceUnits == System.UNIT_METRIC;
        _isMetricElevation = settings.elevationUnits == System.UNIT_METRIC;
        _is24Hour = settings.is24Hour;
    }

    /**
     * Format distance in user's preferred units.
     * @param meters Distance in meters
     * @return Formatted string like "87.5 km" or "54.4 mi"
     */
    function formatDistance(meters) {
        if (meters == null) {
            return "";
        }
        if (_isMetricDistance) {
            var km = meters / 1000.0;
            return km.format("%.1f") + " " + WatchUi.loadResource(Rez.Strings.UnitKm);
        } else {
            var mi = (meters / 1000.0) * KM_TO_MI;
            return mi.format("%.1f") + " " + WatchUi.loadResource(Rez.Strings.UnitMi);
        }
    }

    /**
     * Format elevation in user's preferred units.
     * @param meters Elevation in meters
     * @return Formatted string like "1250 m" or "4101 ft"
     */
    function formatElevation(meters) {
        if (meters == null) {
            return "";
        }
        if (_isMetricElevation) {
            return meters.format("%.0f") + " " + WatchUi.loadResource(Rez.Strings.UnitM);
        } else {
            var ft = meters * M_TO_FT;
            return ft.format("%.0f") + " " + WatchUi.loadResource(Rez.Strings.UnitFt);
        }
    }

    /**
     * Format distance and elevation as a compact string.
     * @param distance Distance in meters
     * @param elevation Elevation in meters
     * @return Formatted string like "87.5 km / 1250 m D+"
     */
    function formatDistanceElevation(distance, elevation) {
        var distStr = formatDistance(distance);
        var elevStr = "";
        if (elevation != null) {
            elevStr =
                formatElevation(elevation) + " " + WatchUi.loadResource(Rez.Strings.UnitDPlus);
        }
        if (distStr.length() > 0 && elevStr.length() > 0) {
            return distStr + " / " + elevStr;
        } else if (distStr.length() > 0) {
            return distStr;
        }
        return elevStr;
    }

    /**
     * Format an ISO 8601 instant string to date and time.
     * @param isoString ISO 8601 string
     * @return Formatted datetime string like "25/01 09:00"
     */
    function formatDateTime(isoString) {
        if (isoString == null) {
            return "";
        }
        var moment = parseIsoDateTime(isoString);
        if (moment == null) {
            return "";
        }
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);

        // Use group time if provided, otherwise use ride datetime's time
        var timeStr;
        if (_is24Hour) {
            timeStr = info.hour.format("%02d") + ":" + info.min.format("%02d");
        } else {
            var hour = info.hour % 12;
            if (hour == 0) {
                hour = 12; // 0:xx and 12:xx both display as 12
            }
            var suffix = WatchUi.loadResource(info.hour >= 12 ? Rez.Strings.PM : Rez.Strings.AM);
            timeStr = hour.format("%02d") + ":" + info.min.format("%02d") + " " + suffix;
        }
        // Date format: DD/MM for 24h (Europe/Asia), MM/DD for 12h (USA)
        var dateStr;
        if (_is24Hour) {
            dateStr = info.day.format("%02d") + "/" + info.month.format("%02d");
        } else {
            dateStr = info.month.format("%02d") + "/" + info.day.format("%02d");
        }
        return dateStr + " " + timeStr;
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
