import Toybox.Application;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

class YamakageWatchFaceApp extends Application.AppBase {
    // The latest terrain payload is kept in memory as well as storage.
    // This lets the face draw the packet on the very next foreground update.
    private var _currentTerrainPacket = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        Application.Storage.deleteValue(FaceKeys.COMPANION_PROBE_STATUS);
        _registerCompanionBridge();
    }

    function onStop(state as Dictionary?) as Void {
        try {
            Complications.registerComplicationChangeCallback(null);
        } catch (e) {}
    }

    function onSettingsChanged() as Void {
        // Mobile/Express setting changes should be reflected immediately.
        WatchUi.requestUpdate();
    }

    // Prefer the in-memory packet, then the cache after a watch-face restart.
    function getTerrainPacket() {
        if (_currentTerrainPacket != null) {
            return _currentTerrainPacket;
        }
        return Application.Storage.getValue(FaceKeys.TERRAIN_PROFILE_RAW);
    }

    function getInitialView() {
        return [new YamakageWatchFaceView(), new YamakageWatchFaceDelegate()];
    }

    function ensureTerrainBackground() as Void {
        // Disabled. Terrain acquisition belongs to the companion app.
    }

    function requestTerrainNow() as Boolean {
        return false;
    }

    function onComplicationChanged(complicationId as Complications.Id) as Void {
        try {
            var complication = Complications.getComplication(complicationId);
            _consumeCompanionComplication(complication);
        } catch (e) {
            // If the publisher disappears Garmin automatically removes the
            // subscription. Cached values naturally age out in the face view.
        }
    }

    private function _registerCompanionBridge() as Void {
        try {
            Complications.registerComplicationChangeCallback(
                method(:onComplicationChanged)
            );

            var iterator = Complications.getComplications();
            var complication = iterator.next();
            while (complication != null) {
                if (_isYamakageComplication(complication)) {
                    _consumeCompanionComplication(complication);
                    try {
                        Complications.subscribeToUpdates(
                            complication.complicationId
                        );
                    } catch (e) {}
                }
                complication = iterator.next();
            }
        } catch (e) {
            // Standalone mode remains fully functional if no compatible
            // publisher exists or complication enumeration is unavailable.
        }
    }

    private function _isYamakageComplication(
        complication as Complications.Complication
    ) as Boolean {
        try {
            var longLabel = complication.longLabel;
            var shortLabel = complication.shortLabel;

            var terrain = longLabel != null &&
                longLabel.equals(FaceConfig.COMPANION_TERRAIN_LABEL);
            var official = shortLabel != null && (
                shortLabel.equals(FaceConfig.OFFICIAL_YK_CSV_LABEL) ||
                shortLabel.equals(FaceConfig.OFFICIAL_YK_CSV_LEGACY_LABEL)
            );

            return terrain || official;
        } catch (e) {
            return false;
        }
    }

    private function _consumeCompanionComplication(
        complication as Complications.Complication
    ) as Void {
        try {
            var longLabel = complication.longLabel;
            var shortLabel = complication.shortLabel;
            var value = complication.value;

            // Official YAMAKAGE public complication. These sunrise/sunset
            // values are already terrain-aware because Tomoo's complication
            // backend calls the full calculateShadow() terrain engine.
            if (
                shortLabel != null &&
                (shortLabel.equals(FaceConfig.OFFICIAL_YK_CSV_LABEL) ||
                 shortLabel.equals(FaceConfig.OFFICIAL_YK_CSV_LEGACY_LABEL)) &&
                value != null && value instanceof String
            ) {
                var yk = CompanionPayload.parseOfficialYkCsv(value as String);
                if (yk == null) {
                    Application.Storage.setValue(
                        FaceKeys.COMPANION_PROBE_STATUS, "YK BAD"
                    );
                    WatchUi.requestUpdate();
                    return;
                }

                var status = yk[2].toNumber();
                Application.Storage.setValue(FaceKeys.API_STATUS, status);
                if (status == 0) {
                    var stamp = yk[1].toNumber();
                    Application.Storage.setValue(FaceKeys.SUNRISE, yk[3]);
                    Application.Storage.setValue(FaceKeys.SUNSET, yk[4]);
                    Application.Storage.setValue(FaceKeys.MOONRISE, yk[5]);
                    Application.Storage.setValue(FaceKeys.MOONSET, yk[6]);
                    Application.Storage.setValue(FaceKeys.MOON_PHASE, yk[7]);
                    Application.Storage.setValue(FaceKeys.MOON_FRACTION, yk[8]);
                    Application.Storage.setValue(FaceKeys.OFFICIAL_YK_ALTITUDE, yk[9]);
                    Application.Storage.setValue(FaceKeys.OFFICIAL_YK_TIME, stamp);
                    Application.Storage.setValue(FaceKeys.SUMMARY_TIME, stamp);
                    Application.Storage.setValue(
                        FaceKeys.COMPANION_PROBE_STATUS, "YK RX"
                    );
                } else {
                    Application.Storage.setValue(
                        FaceKeys.COMPANION_PROBE_STATUS,
                        "YK E" + status.toString()
                    );
                }
                WatchUi.requestUpdate();
                return;
            }

            // Existing terrain-profile complication from our companion build.
            if (
                longLabel != null &&
                longLabel.equals(FaceConfig.COMPANION_TERRAIN_LABEL) &&
                value != null && value instanceof String
            ) {
                var raw = value as String;
                if (
                    raw.length() >= 16 && raw.length() <= 512 &&
                    raw.find("T2|") == 0
                ) {
                    Application.Storage.setValue(
                        FaceKeys.TERRAIN_PROFILE_RAW, raw
                    );
                    _currentTerrainPacket = raw;
                    Application.Storage.setValue(
                        FaceKeys.TERRAIN_RX_TIME, Time.now().value()
                    );
                    Application.Storage.setValue(
                        FaceKeys.COMPANION_PROBE_STATUS, "TRN RX"
                    );
                } else {
                    Application.Storage.setValue(
                        FaceKeys.COMPANION_PROBE_STATUS, "TRN BAD"
                    );
                }
                WatchUi.requestUpdate();
            }
        } catch (e) {
            Application.Storage.setValue(
                FaceKeys.COMPANION_PROBE_STATUS,
                "CMP ERR"
            );
            WatchUi.requestUpdate();
        }
    }


}

function getApp() as YamakageWatchFaceApp {
    return Application.getApp() as YamakageWatchFaceApp;
}
