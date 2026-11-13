import Toybox.Lang;

module CompanionPayload {

    // Official YAMAKAGE complication V1 (shortLabel: "YK CSV"):
    // VERSION,TIMESTAMP,STATUS,SUNRISE,SUNSET,MOONRISE,MOONSET,
    // MOON_PHASE,MOON_FRACTION,ALTITUDE
    //
    // Returns the same 10 scalar fields in schema order, or null.
    function parseOfficialYkCsv(value as String) as Array? {
        var parts = _split(value, ",");
        if (parts.size() < 10) { return null; }

        var version = parts[0].toNumber();
        var stamp = parts[1].toLong();
        var status = parts[2].toNumber();
        var sunrise = parts[3].toLong();
        var sunset = parts[4].toLong();
        var moonrise = parts[5].toLong();
        var moonset = parts[6].toLong();
        var phase = parts[7].toFloat();
        var fraction = parts[8].toFloat();
        var altitude = parts[9].toFloat();

        if (
            version == null || version != 1 || stamp == null || status == null ||
            sunrise == null || sunset == null || moonrise == null ||
            moonset == null || phase == null || fraction == null || altitude == null
        ) {
            return null;
        }

        return [
            version, stamp, status, sunrise, sunset,
            moonrise, moonset, phase, fraction, altitude
        ];
    }

    // Preferred:
    //   E2|sunrise|sunset|sunUpdated|moonrise|moonset|moonUpdated
    // Legacy alpha:
    //   E1|sunrise|sunset|moonrise|moonset|publishedUnix
    //
    // Returns:
    // [sunrise, sunset, sunStamp, moonrise, moonset, moonStamp]
    function parseEvents(value as String) as Array? {
        var parts = _split(value, "|");

        if (parts.size() >= 7 && parts[0].equals("E2")) {
            var sunrise2 = parts[1].toLong();
            var sunset2 = parts[2].toLong();
            var sunStamp2 = parts[3].toLong();
            var moonrise2 = parts[4].toLong();
            var moonset2 = parts[5].toLong();
            var moonStamp2 = parts[6].toLong();

            if (
                sunrise2 == null ||
                sunset2 == null ||
                sunStamp2 == null ||
                moonrise2 == null ||
                moonset2 == null ||
                moonStamp2 == null
            ) {
                return null;
            }

            return [
                sunrise2,
                sunset2,
                sunStamp2,
                moonrise2,
                moonset2,
                moonStamp2
            ];
        }

        if (parts.size() >= 6 && parts[0].equals("E1")) {
            var sunrise1 = parts[1].toLong();
            var sunset1 = parts[2].toLong();
            var moonrise1 = parts[3].toLong();
            var moonset1 = parts[4].toLong();
            var stamp1 = parts[5].toLong();

            if (
                sunrise1 == null ||
                sunset1 == null ||
                moonrise1 == null ||
                moonset1 == null ||
                stamp1 == null
            ) {
                return null;
            }

            return [
                sunrise1,
                sunset1,
                stamp1,
                moonrise1,
                moonset1,
                stamp1
            ];
        }

        return null;
    }

    // Preferred:
    //   T2|15|terrainUpdated|e0,e15,...,e345
    // Legacy alpha:
    //   T1|15|e0,e15,...,e345
    //
    // Returns [stepDeg, Array<Number>, terrainStamp].
    function parseTerrain(value as String) as Array? {
        var parts = _split(value, "|");
        var step = null;
        var stamp = -1l;
        var valuesField = null;

        if (parts.size() >= 4 && parts[0].equals("T2")) {
            step = parts[1].toNumber();
            stamp = parts[2].toLong();
            valuesField = parts[3];
        } else if (parts.size() >= 3 && parts[0].equals("T1")) {
            step = parts[1].toNumber();
            valuesField = parts[2];
        } else {
            return null;
        }

        if (
            step == null ||
            step <= 0 ||
            stamp == null ||
            valuesField == null
        ) {
            return null;
        }

        var tokens = _split(valuesField as String, ",");
        if (tokens.size() < 3) {
            return null;
        }

        var values = [] as Array<Number>;
        for (var i = 0; i < tokens.size(); i++) {
            var n = tokens[i].toNumber();
            if (n == null) {
                return null;
            }
            values.add(n);
        }

        return [step, values, stamp];
    }

    // String.split is API 6.0.3; the face's minimum is 4.2.
    function _split(value as String, delim as String) as Array<String> {
        var result = [] as Array<String>;
        var start = 0;
        var length = value.length();
        var delimLength = delim.length();

        while (start <= length) {
            var tail = value.substring(start, length);
            if (tail == null) {
                break;
            }

            var rel = tail.find(delim);
            if (rel == null) {
                result.add(tail);
                break;
            }

            var end = start + rel;
            var token = value.substring(start, end);
            result.add(token == null ? "" : token);
            start = end + delimLength;

            if (start == length) {
                result.add("");
                break;
            }
        }

        return result;
    }
}
