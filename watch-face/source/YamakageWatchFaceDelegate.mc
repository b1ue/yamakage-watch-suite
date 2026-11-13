import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class YamakageWatchFaceDelegate extends WatchUi.WatchFaceDelegate {
    function initialize() {
        WatchFaceDelegate.initialize();
    }


    // Press the lower/terrain area to jump into the full YAMAKAGE device app
    // when it is installed. This is intentionally optional: the watch face is
    // still fully usable by itself.
    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        return false;
    }
}
