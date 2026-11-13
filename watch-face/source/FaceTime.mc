import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

module FaceTime {
    function clockText(showColon as Boolean) as String {
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var hour = _displayHour(info.hour);
        if (showColon) {
            return Lang.format("$1$:$2$", [
                hour.format("%02d"),
                info.min.format("%02d")
            ]);
        }
        return Lang.format("$1$$2$", [
            hour.format("%02d"),
            info.min.format("%02d")
        ]);
    }

    function secondsText() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return info.sec.format("%02d");
    }

    function dateText() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return Lang.format("$1$/$2$", [
            (info.month as Number).format("%02d"),
            info.day.format("%02d")
        ]);
    }

    function eventText(value) as String {
        if (value == null || !(value instanceof Number || value instanceof Long) || value <= 0) {
            return "--:--";
        }
        var info = Gregorian.info(new Time.Moment(value.toNumber()), Time.FORMAT_SHORT);
        var hour = _displayHour(info.hour);
        return Lang.format("$1$:$2$", [
            hour.format("%02d"),
            info.min.format("%02d")
        ]);
    }

    function daylightText(sunrise, sunset) as String {
        if (
            sunrise == null || sunset == null ||
            !(sunrise instanceof Number || sunrise instanceof Long) ||
            !(sunset instanceof Number || sunset instanceof Long)
        ) {
            return "DAY --h --m";
        }

        var delta = sunset.toNumber() - sunrise.toNumber();
        if (delta <= 0) {
            return "DAY --h --m";
        }

        var hours = delta / 3600;
        var mins = (delta % 3600) / 60;
        return "DAY " + hours.format("%d") + "h " + mins.format("%02d") + "m";
    }

    function daylightRemainingText(sunrise, sunset) as String {
        if (
            sunrise == null || sunset == null ||
            !(sunrise instanceof Number || sunrise instanceof Long) ||
            !(sunset instanceof Number || sunset instanceof Long)
        ) {
            return "LIGHT --:--";
        }

        var rise = sunrise.toNumber();
        var set = sunset.toNumber();
        var now = Time.now().value();

        if (rise <= 0 || set <= rise) {
            return "LIGHT --:--";
        }

        if (now >= rise && now < set) {
            var remaining = set - now;
            var hours = remaining / 3600;
            var mins = (remaining % 3600) / 60;
            return "LIGHT " + hours.format("%d") + ":" +
                mins.format("%02d");
        }

        if (now < rise) {
            var untilRise = rise - now;
            var riseHours = untilRise / 3600;
            var riseMins = (untilRise % 3600) / 60;
            return "SUN " + riseHours.format("%d") + ":" +
                riseMins.format("%02d");
        }

        return "NIGHT";
    }

    function ageCompact(value, prefix as String) as String {
        if (value == null || !(value instanceof Number || value instanceof Long) || value <= 0) {
            return prefix + " --";
        }

        var age = Time.now().value() - value.toNumber();
        if (age < 0) {
            age = 0;
        }
        if (age < 60) {
            return prefix + " NOW";
        }
        if (age < 3600) {
            return prefix + " " + (age / 60).format("%d") + "m";
        }
        if (age < 86400) {
            return prefix + " " + (age / 3600).format("%d") + "h";
        }
        return prefix + " " + (age / 86400).format("%d") + "d";
    }

    function _displayHour(hour24 as Number) as Number {
        if (System.getDeviceSettings().is24Hour) {
            return hour24;
        }
        var hour = hour24 % 12;
        return hour == 0 ? 12 : hour;
    }
}
