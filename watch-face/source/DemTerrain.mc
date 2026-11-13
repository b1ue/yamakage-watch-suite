import Toybox.Lang;
import Toybox.Math;

// Coarse terrain fallback for the watch face. The background service asks the
// public Open-Meteo elevation endpoint for 18 bearings x 3 radii plus the
// observer point (55 coordinates total). The resulting apparent horizon is
// cached and reused until the saved location moves materially.
module DemTerrain {
    const BEARING_STEP_DEG = 20;
    const BEARING_COUNT = 18;
    const RADII_COUNT = 3;
    const EARTH_RADIUS_KM = 6371.0;
    const EFFECTIVE_EARTH_RADIUS_M = 6371000.0 * 7.0 / 6.0;

    function radiusKm(index as Number) {
        switch (index) {
            case 0: return 0.75;
            case 1: return 6.0;
            default: return 28.0;
        }
    }

    function buildRequestUrl(baseUrl as String, lat, lon) as String {
        var latList = lat.format("%.4f");
        var lonList = lon.format("%.4f");

        for (var bearingIndex = 0; bearingIndex < BEARING_COUNT; bearingIndex++) {
            var bearing = bearingIndex.toDouble() * BEARING_STEP_DEG.toDouble();
            for (var radiusIndex = 0; radiusIndex < RADII_COUNT; radiusIndex++) {
                var point = destinationPoint(lat, lon, bearing, radiusKm(radiusIndex));
                latList += "," + point[0].format("%.4f");
                lonList += "," + point[1].format("%.4f");
            }
        }

        return baseUrl + "?latitude=" + latList + "&longitude=" + lonList;
    }

    function destinationPoint(
        lat,
        lon,
        bearingDeg,
        distanceKm
    ) {
        var lat1 = degToRad(lat);
        var lon1 = degToRad(lon);
        var bearing = degToRad(bearingDeg);
        var angular = distanceKm / EARTH_RADIUS_KM;

        var sinLat1 = Math.sin(lat1);
        var cosLat1 = Math.cos(lat1);
        var sinAngular = Math.sin(angular);
        var cosAngular = Math.cos(angular);

        var lat2 = Math.asin(
            sinLat1 * cosAngular +
            cosLat1 * sinAngular * Math.cos(bearing)
        );
        var lon2 = lon1 + Math.atan2(
            Math.sin(bearing) * sinAngular * cosLat1,
            cosAngular - sinLat1 * Math.sin(lat2)
        );

        var lonDeg = radToDeg(lon2);
        while (lonDeg < -180.0) { lonDeg += 360.0; }
        while (lonDeg > 180.0) { lonDeg -= 360.0; }

        return [radToDeg(lat2), lonDeg];
    }

    // Elevation array order must match buildRequestUrl: center first, then
    // each bearing with RADII_COUNT distances. Returns tenths of degrees.
    function buildHorizon(elevations as Array) as Array<Number>? {
        var expected = 1 + BEARING_COUNT * RADII_COUNT;
        if (elevations.size() < expected) {
            return null;
        }

        var center = elevations[0];
        if (!(center instanceof Number || center instanceof Float || center instanceof Double)) {
            return null;
        }
        var centerM = center.toDouble();
        var values = [] as Array<Number>;
        var cursor = 1;

        for (var bearingIndex = 0; bearingIndex < BEARING_COUNT; bearingIndex++) {
            var maxAngle = -5.0;
            for (var radiusIndex = 0; radiusIndex < RADII_COUNT; radiusIndex++) {
                var value = elevations[cursor];
                cursor = cursor + 1;
                if (!(value instanceof Number || value instanceof Float || value instanceof Double)) {
                    continue;
                }

                var distanceKm = radiusKm(radiusIndex);
                var distanceM = distanceKm * 1000.0;
                // Approximate curvature using a 7/6 effective Earth radius to
                // allow for ordinary atmospheric refraction near the horizon.
                var curvatureM =
                    (distanceM * distanceM) / (2.0 * EFFECTIVE_EARTH_RADIUS_M);
                var relativeM = value.toDouble() - centerM - curvatureM;
                var angle = radToDeg(Math.atan2(relativeM, distanceM));
                if (angle > maxAngle) {
                    maxAngle = angle;
                }
            }

            if (maxAngle < -5.0) { maxAngle = -5.0; }
            if (maxAngle > 45.0) { maxAngle = 45.0; }
            values.add(Math.round(maxAngle * 10.0));
        }

        return values;
    }

    function encodeProfile(values as Array<Number>) as String {
        var result = "T1|" + BEARING_STEP_DEG.format("%d") + "|";
        for (var i = 0; i < values.size(); i++) {
            if (i > 0) {
                result += ",";
            }
            result += values[i].format("%d");
        }
        return result;
    }

    function distanceKm(
        lat1,
        lon1,
        lat2,
        lon2
    ) {
        var p1 = degToRad(lat1);
        var p2 = degToRad(lat2);
        var dp = degToRad(lat2 - lat1);
        var dl = degToRad(lon2 - lon1);
        var a =
            Math.sin(dp / 2.0) * Math.sin(dp / 2.0) +
            Math.cos(p1) * Math.cos(p2) *
            Math.sin(dl / 2.0) * Math.sin(dl / 2.0);
        if (a < 0.0) { a = 0.0; }
        if (a > 1.0) { a = 1.0; }
        var c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));
        return EARTH_RADIUS_KM * c;
    }

    function degToRad(value) {
        return value * Math.PI / 180.0;
    }

    function radToDeg(value) {
        return value * 180.0 / Math.PI;
    }
}
