import Toybox.Lang;
import Toybox.Graphics;
import Shared.Core.Consts;
import Shared.Core.Enums.TargetMode;

module Features {
    module Main {
        module Components {
            module MainTitle {
                function render(
                    dc as Graphics.Dc,
                    cx as Number,
                    y as Number,
                    font as Graphics.FontType,
                    mode as Number
                ) as Void {
                    dc.setColor(
                        mode == TargetMode.SUN
                            ? Graphics.COLOR_ORANGE
                            : Graphics.COLOR_BLUE,
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.drawText(
                        cx,
                        y,
                        font,
                        Consts.APP_TITLE,
                        Graphics.TEXT_JUSTIFY_CENTER |
                            Graphics.TEXT_JUSTIFY_VCENTER
                    );
                }
            }
        }
    }
}
