import Toybox.Application;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Core.ApiSchema.SunDataIndex;
import Core.ApiSchema.MoonDataIndex;

module Shared {
    module CompanionPublisher {
        // Keep IDs stable: they are defined in resources/complications/complications.xml.
        const EVENTS_ID = 0;
        const TERRAIN_ID = 1;

        const STORE_SUNRISE = "companion_sunrise";
        const STORE_SUNSET = "companion_sunset";
        const STORE_MOONRISE = "companion_moonrise";
        const STORE_MOONSET = "companion_moonset";
        const STORE_TERRAIN = "companion_terrain";
        const STORE_SUN_UPDATED = "companion_sun_updated";
        const STORE_MOON_UPDATED = "companion_moon_updated";
        const STORE_TERRAIN_UPDATED = "companion_terrain_updated";

        // Compact wire formats consumed by the sibling watch face:
        //   E2|sunrise|sunset|sunUpdated|moonrise|moonset|moonUpdated
        //   T2|stepDegrees|terrainUpdated|elevationTenths,...
        //
        // Domain-specific timestamps stop a later Moon calculation from making
        // older Sun data look fresh (and vice versa).
        const EVENTS_VERSION = "E2";
        const TERRAIN_VERSION = "T2";
        const TERRAIN_STEP_DEG = 15;

        function publishSun(payload as Array) as Void {
            if (payload.size() <= SunDataIndex.PROFILES) {
                return;
            }

            _storeEvent(STORE_SUNSET, payload[SunDataIndex.SET_TIME]);
            _storeEvent(STORE_SUNRISE, payload[SunDataIndex.RISE_TIME]);
            Application.Storage.setValue(
                STORE_SUN_UPDATED,
                Time.now().value()
            );

            var profiles = payload[SunDataIndex.PROFILES];
            var stepDeg = payload[SunDataIndex.AZIMUTH_STEP];
            _storeTerrain(profiles, stepDeg);

            republish();
        }

        function publishMoon(payload as Array) as Void {
            if (payload.size() <= MoonDataIndex.PROFILES) {
                return;
            }

            _storeEvent(STORE_MOONSET, payload[MoonDataIndex.SET_TIME]);
            _storeEvent(STORE_MOONRISE, payload[MoonDataIndex.RISE_TIME]);
            Application.Storage.setValue(
                STORE_MOON_UPDATED,
                Time.now().value()
            );

            // Sun and moon requests use the same terrain repository/profile.
            // Publishing again keeps the face's horizon fresh even if Moon mode
            // is the first calculation performed after travel.
            var profiles = payload[MoonDataIndex.PROFILES];
            var stepDeg = payload[MoonDataIndex.AZIMUTH_STEP];
            _storeTerrain(profiles, stepDeg);

            republish();
        }

        // Publish a locally sampled fallback horizon. Values are already
        // elevation angles in tenths of a degree at the supplied step.
        // Publish locally sampled fallback horizon and report whether
        // Garmin accepted the complication update.
        function publishApproxTerrain(
            values as Array,
            stepDeg as Number
        ) as Boolean {
            if (values.size() < 3 || stepDeg <= 0) {
                return false;
            }

            var stamp = Time.now().value();
            var out = TERRAIN_VERSION + "|" +
                stepDeg.toString() + "|" +
                stamp.toString() + "|";

            for (var i = 0; i < values.size(); i++) {
                if (i > 0) {
                    out += ",";
                }
                out += values[i].toString();
            }

            Application.Storage.setValue(STORE_TERRAIN, out);
            Application.Storage.setValue(STORE_TERRAIN_UPDATED, stamp);

            if (!_canPublish()) {
                return false;
            }

            try {
                Complications.updateComplication(TERRAIN_ID, {
                    :value => out,
                    :shortLabel => "TRN"
                });
                return true;
            } catch (e) {
                return false;
            }
        }

        function republish() as Void {
            if (!_canPublish()) {
                return;
            }

            try {
                Complications.updateComplication(EVENTS_ID, {
                    :value => _buildEventsValue(),
                    :shortLabel => "YMK"
                });
            } catch (e) {
                // Companion publishing must never interfere with the full app.
            }

            var terrain = Application.Storage.getValue(STORE_TERRAIN);
            if (terrain != null && terrain instanceof String) {
                try {
                    Complications.updateComplication(TERRAIN_ID, {
                        :value => terrain,
                        :shortLabel => "TRN"
                    });
                } catch (e) {}
            }
        }

        function _canPublish() as Boolean {
            try {
                return (Toybox has :Complications) &&
                    (Complications has :updateComplication);
            } catch (e) {
                return false;
            }
        }

        function _storeEvent(key as String, value) as Void {
            if (
                value != null &&
                (value instanceof Number || value instanceof Long)
            ) {
                Application.Storage.setValue(key, value);
            }
        }

        function _buildEventsValue() as String {
            return EVENTS_VERSION +
                "|" + _storedEvent(STORE_SUNRISE) +
                "|" + _storedEvent(STORE_SUNSET) +
                "|" + _storedTimestamp(STORE_SUN_UPDATED) +
                "|" + _storedEvent(STORE_MOONRISE) +
                "|" + _storedEvent(STORE_MOONSET) +
                "|" + _storedTimestamp(STORE_MOON_UPDATED);
        }

        function _storedEvent(key as String) as String {
            var value = Application.Storage.getValue(key);
            if (
                value != null &&
                (value instanceof Number || value instanceof Long) &&
                value.toNumber() > 0
            ) {
                return value.toString();
            }
            return "-1";
        }

        function _storedTimestamp(key as String) as String {
            var value = Application.Storage.getValue(key);
            if (
                value != null &&
                (value instanceof Number || value instanceof Long) &&
                value.toNumber() > 0
            ) {
                return value.toString();
            }
            return "-1";
        }

        function _storeTerrain(profiles, stepDeg) as Void {
            if (
                profiles == null ||
                !(profiles instanceof Array) ||
                profiles.size() == 0 ||
                stepDeg == null ||
                !(stepDeg instanceof Number)
            ) {
                return;
            }

            var stamp = Time.now().value();
            var encoded = _encodeTerrain(
                profiles as Array,
                stepDeg as Number,
                stamp
            );
            if (encoded != null) {
                Application.Storage.setValue(STORE_TERRAIN, encoded);
                Application.Storage.setValue(
                    STORE_TERRAIN_UPDATED,
                    stamp
                );
            }
        }

        function _encodeTerrain(
            profiles as Array,
            sourceStep as Number,
            stamp as Number
        ) as String? {
            if (sourceStep <= 0 || profiles.size() == 0) {
                return null;
            }

            var out = TERRAIN_VERSION + "|" +
                TERRAIN_STEP_DEG.toString() + "|" +
                stamp.toString() + "|";
            var first = true;

            for (
                var az = 0;
                az < 360;
                az += TERRAIN_STEP_DEG
            ) {
                var idx = (az.toFloat() / sourceStep.toFloat()).toNumber();
                if (idx < 0) {
                    idx = 0;
                }
                if (idx >= profiles.size()) {
                    idx = profiles.size() - 1;
                }

                var row = profiles[idx];
                var angleTenths = 0;
                if (
                    row != null &&
                    row instanceof Array &&
                    row.size() > 0 &&
                    row[0] != null &&
                    (row[0] instanceof Number || row[0] instanceof Float)
                ) {
                    angleTenths = Math.round(row[0].toFloat() * 10.0);
                }

                if (!first) {
                    out += ",";
                }
                out += angleTenths.toString();
                first = false;
            }

            return out;
        }
    }
}
