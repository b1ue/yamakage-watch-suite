import Toybox.Lang;
import Toybox.Math;

// Lightweight NOAA-style solar-position calculation. The watch face already
// obtains a cached latitude/longitude from Activity.Info.currentLocation; this
// module turns that coordinate plus UTC epoch time into approximate solar
// azimuth/elevation without waking GPS or requiring the phone/network.
module SolarPosition {
    function calculate(lat as Double, lon as Double, unixTime as Number or Long) as Array? {
        try {
            var epoch = unixTime.toDouble();
            var jd = epoch / 86400.0 + 2440587.5;
            var t = (jd - 2451545.0) / 36525.0;

            var l0 = _normalizeDegrees(
                280.46646 + t * (36000.76983 + t * 0.0003032)
            );
            var m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
            var ecc = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);

            var mRad = _degToRad(m);
            var center =
                Math.sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
                Math.sin(2.0 * mRad) * (0.019993 - 0.000101 * t) +
                Math.sin(3.0 * mRad) * 0.000289;

            var trueLong = l0 + center;
            var omega = 125.04 - 1934.136 * t;
            var appLong = trueLong - 0.00569 - 0.00478 * Math.sin(_degToRad(omega));

            var meanObliq =
                23.0 +
                (26.0 +
                    ((21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60.0)) /
                    60.0;
            var obliq = meanObliq + 0.00256 * Math.cos(_degToRad(omega));
            var obliqRad = _degToRad(obliq);
            var appLongRad = _degToRad(appLong);
            var decl = Math.asin(Math.sin(obliqRad) * Math.sin(appLongRad));

            var y = Math.tan(obliqRad / 2.0);
            y *= y;
            var l0Rad = _degToRad(l0);
            var eqTime = 4.0 * _radToDeg(
                y * Math.sin(2.0 * l0Rad) -
                2.0 * ecc * Math.sin(mRad) +
                4.0 * ecc * y * Math.sin(mRad) * Math.cos(2.0 * l0Rad) -
                0.5 * y * y * Math.sin(4.0 * l0Rad) -
                1.25 * ecc * ecc * Math.sin(2.0 * mRad)
            );

            var daySeconds = unixTime.toNumber() % 86400;
            if (daySeconds < 0) {
                daySeconds += 86400;
            }
            var utcMinutes = daySeconds.toDouble() / 60.0;
            var trueSolarMinutes = utcMinutes + eqTime + 4.0 * lon;
            while (trueSolarMinutes < 0.0) {
                trueSolarMinutes += 1440.0;
            }
            while (trueSolarMinutes >= 1440.0) {
                trueSolarMinutes -= 1440.0;
            }

            var hourAngle = trueSolarMinutes / 4.0 - 180.0;
            var haRad = _degToRad(hourAngle);
            var latRad = _degToRad(lat);

            var cosZenith =
                Math.sin(latRad) * Math.sin(decl) +
                Math.cos(latRad) * Math.cos(decl) * Math.cos(haRad);
            if (cosZenith > 1.0) { cosZenith = 1.0; }
            if (cosZenith < -1.0) { cosZenith = -1.0; }

            var zenith = _radToDeg(Math.acos(cosZenith));
            var elevation = 90.0 - zenith;

            var azimuth = _radToDeg(
                Math.atan2(
                    Math.sin(haRad),
                    Math.cos(haRad) * Math.sin(latRad) -
                        Math.tan(decl) * Math.cos(latRad)
                )
            ) + 180.0;
            azimuth = _normalizeDegrees(azimuth);

            return [azimuth, elevation];
        } catch (e) {
            return null;
        }
    }

    function _normalizeDegrees(value as Double) as Double {
        var v = value;
        while (v < 0.0) { v += 360.0; }
        while (v >= 360.0) { v -= 360.0; }
        return v;
    }

    function _degToRad(value as Double) as Double {
        return value * Math.PI / 180.0;
    }

    function _radToDeg(value as Double) as Double {
        return value * 180.0 / Math.PI;
    }
}
