import Toybox.Communications;
import Toybox.Lang;
import Toybox.Math;

module Shared {
    module DemTerrainFallback {
        const ELEVATION_URL = "https://api.open-meteo.com/v1/elevation";
        const BEARING_STEP_DEG = 20;
        const BEARING_COUNT = 18;
        const RADII_COUNT = 3;

        typedef CallbackMethod as
            (Method(responseCode as Number, data as Dictionary?) as Void);

        function request(
            lat as Float,
            lon as Float,
            callback as CallbackMethod
        ) as Void {
            var url = _buildRequestUrl(lat, lon);
            var options = {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType =>
                    Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            };

            Communications.makeWebRequest(
                url,
                {},
                options,
                callback
            );
        }

        function buildHorizon(elevations as Array) as Array? {
            var expected = 1 + BEARING_COUNT * RADII_COUNT;
            if (elevations.size() < expected) {
                return null;
            }

            var observer = elevations[0];
            if (
                observer == null ||
                !(observer instanceof Number || observer instanceof Float)
            ) {
                return null;
            }

            var out = [] as Array<Number>;
            var cursor = 1;

            for (var b = 0; b < BEARING_COUNT; b++) {
                var maxAngle = -5.0;

                for (var r = 0; r < RADII_COUNT; r++) {
                    var e = elevations[cursor];
                    cursor = cursor + 1;

                    if (
                        e == null ||
                        !(e instanceof Number || e instanceof Float)
                    ) {
                        continue;
                    }

                    var distanceKm = _radiusKm(r);
                    var distanceM = distanceKm * 1000.0;

                    // Approximate Earth curvature with standard atmospheric
                    // refraction correction (effective 7/6 Earth radius).
                    var effectiveEarthRadiusM = 6371000.0 * (7.0 / 6.0);
                    var curvature =
                        (distanceM * distanceM) /
                        (2.0 * effectiveEarthRadiusM);

                    var relativeHeight =
                        e.toFloat() - observer.toFloat() - curvature;
                    var angle =
                        Math.atan2(relativeHeight, distanceM) *
                        180.0 / Math.PI;

                    if (angle > maxAngle) {
                        maxAngle = angle;
                    }
                }

                out.add(Math.round(maxAngle * 10.0).toNumber());
            }

            return out;
        }

        function _radiusKm(index as Number) {
            switch (index) {
                case 0: return 0.75;
                case 1: return 6.0;
                default: return 28.0;
            }
        }

        function _buildRequestUrl(
            lat as Float,
            lon as Float
        ) as String {
            var lats = lat.format("%.6f");
            var lons = lon.format("%.6f");

            for (var b = 0; b < BEARING_COUNT; b++) {
                var bearing =
                    b.toFloat() * BEARING_STEP_DEG.toFloat();
                var bearingRad = bearing * Math.PI / 180.0;

                for (var r = 0; r < RADII_COUNT; r++) {
                    var distanceKm = _radiusKm(r);

                    // Sufficient for <= 28 km terrain sampling.
                    var dLat =
                        (distanceKm / 111.32) * Math.cos(bearingRad);
                    var cosLat = Math.cos(lat * Math.PI / 180.0);
                    if (Math.abs(cosLat) < 0.01) {
                        cosLat = 0.01;
                    }
                    var dLon =
                        (distanceKm / (111.32 * cosLat)) *
                        Math.sin(bearingRad);

                    lats += "," + (lat + dLat).format("%.6f");
                    lons += "," + (lon + dLon).format("%.6f");
                }
            }

            return ELEVATION_URL +
                "?latitude=" + lats +
                "&longitude=" + lons;
        }
    }
}
