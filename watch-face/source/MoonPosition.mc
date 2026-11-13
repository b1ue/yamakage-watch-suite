import Toybox.Lang;
import Toybox.Math;

// Low-cost geocentric lunar position based on the Moon's main orbital terms.
// Returns [azimuth clockwise from north, elevation, phase(0..1), illuminated
// fraction(0..1)]. Typical precision is adequate for a compressed watch-face
// display but does NOT replace topocentric lunar-rise calculations.
module MoonPosition {
    function calculate(
        lat as Double,
        lon as Double,
        unixTime as Number or Long
    ) as Array? {
        try {
            var d = unixTime.toDouble() / 86400.0 - 10957.5;
            var rad = Math.PI / 180.0;
            var l = (218.316 + 13.176396 * d) * rad;
            var m = (134.963 + 13.064993 * d) * rad;
            var f = (93.272 + 13.229350 * d) * rad;
            var eclLon = l + 6.289 * rad * Math.sin(m);
            var eclLat = 5.128 * rad * Math.sin(f);
            var obliq = 23.4397 * rad;
            var ra = Math.atan2(
                Math.sin(eclLon) * Math.cos(obliq) -
                    Math.tan(eclLat) * Math.sin(obliq),
                Math.cos(eclLon)
            );
            var decl = Math.asin(
                Math.sin(eclLat) * Math.cos(obliq) +
                Math.cos(eclLat) * Math.sin(obliq) * Math.sin(eclLon)
            );
            var sidereal = (280.16 + 360.9856235 * d + lon) * rad;
            var hourAngle = sidereal - ra;
            var latitude = lat * rad;
            var sinAlt = Math.sin(latitude) * Math.sin(decl) +
                Math.cos(latitude) * Math.cos(decl) * Math.cos(hourAngle);
            if (sinAlt < -1.0) { sinAlt = -1.0; }
            if (sinAlt > 1.0) { sinAlt = 1.0; }
            var alt = Math.asin(sinAlt) / rad;
            var az = Math.atan2(
                Math.sin(hourAngle),
                Math.cos(hourAngle) * Math.sin(latitude) -
                    Math.tan(decl) * Math.cos(latitude)
            ) / rad + 180.0;
            while (az < 0.0) { az += 360.0; }
            while (az >= 360.0) { az -= 360.0; }

            // Phase approximation from the lunar and solar ecliptic longitude.
            var solarM = (357.529 + 0.98560028 * d) * rad;
            var solarL = (280.459 + 0.98564736 * d) * rad +
                1.915 * rad * Math.sin(solarM) +
                0.020 * rad * Math.sin(2.0 * solarM);
            var difference = eclLon - solarL;
            while (difference < 0.0) { difference += 2.0 * Math.PI; }
            while (difference >= 2.0 * Math.PI) {
                difference -= 2.0 * Math.PI;
            }
            var phase = difference / (2.0 * Math.PI);
            var illuminated = (1.0 - Math.cos(difference)) / 2.0;
            return [az, alt, phase, illuminated];
        } catch (e) {
            return null;
        }
    }
}
