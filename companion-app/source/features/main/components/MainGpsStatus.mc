import Toybox.Lang;
import Toybox.Graphics;

module Features {
    module Main {
        module Components {
            module MainGpsStatus {
                function render(
                    dc as Graphics.Dc,
                    cx as Number,
                    y as Number,
                    gpsText as String,
                    gpsColor as Graphics.ColorType
                ) as Void {
                    dc.setColor(gpsColor, Graphics.COLOR_TRANSPARENT);
                    var textWidth = dc.getTextWidthInPixels(
                        gpsText,
                        Graphics.FONT_XTINY
                    );
                    dc.fillCircle(cx - textWidth / 2 - 6, y, 2);
                    dc.drawText(
                        cx,
                        y,
                        Graphics.FONT_XTINY,
                        gpsText,
                        Graphics.TEXT_JUSTIFY_CENTER |
                            Graphics.TEXT_JUSTIFY_VCENTER
                    );
                }
            }
        }
    }
}
