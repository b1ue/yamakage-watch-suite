import Toybox.Lang;
import Toybox.Graphics;
import Shared.Core.Enums.TargetMode;

module Features {
    module Main {
        module Components {
            module MainClock {
                function render(
                    dc as Graphics.Dc,
                    cx as Number,
                    y as Number,
                    font as Graphics.FontType,
                    clockText as String,
                    dateText as String,
                    mode as Number
                ) as Void {
                    dc.setColor(
                        Graphics.COLOR_WHITE,
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.drawText(
                        cx,
                        y,
                        font,
                        clockText,
                        Graphics.TEXT_JUSTIFY_CENTER |
                            Graphics.TEXT_JUSTIFY_VCENTER
                    );

                    dc.setColor(
                        Graphics.COLOR_LT_GRAY,
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.drawText(
                        cx,
                        y + dc.getFontHeight(font) / 2 + 4,
                        Graphics.FONT_XTINY,
                        (mode == TargetMode.SUN
                            ? "DAYLIGHT  "
                            : "MOONLIGHT  ") + dateText,
                        Graphics.TEXT_JUSTIFY_CENTER |
                            Graphics.TEXT_JUSTIFY_VCENTER
                    );
                }
            }
        }
    }
}
