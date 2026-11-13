import Toybox.Lang;
import Toybox.Graphics;
import Shared.Core.Enums.TargetMode;

module Features {
    module Main {
        module Components {
            module MainBackground {
                function render(
                    dc as Graphics.Dc,
                    w as Number,
                    h as Number,
                    mode as Number
                ) as Void {
                    _BackgroundMountain.render(dc, h, w);
                    _ForegroundMountain.render(dc, h, w, mode);
                }
            }

            module _ForegroundMountain {
                function render(
                    dc as Graphics.Dc,
                    h as Number,
                    w as Number,
                    mode as Number
                ) as Void {
                    dc.setColor(
                        mode == TargetMode.SUN
                            ? Graphics.COLOR_DK_GREEN
                            : Graphics.COLOR_DK_BLUE,
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.fillPolygon([
                        [0, h],
                        [(w * 0.25).toNumber(), (h * 0.65).toNumber()],
                        [(w * 0.5).toNumber(), (h * 0.8).toNumber()],
                        [(w * 0.9).toNumber(), (h * 0.6).toNumber()],
                        [w, (h * 0.75).toNumber()],
                        [w, h]
                    ]);

                    dc.setColor(
                        mode == TargetMode.SUN
                            ? Graphics.COLOR_GREEN
                            : Graphics.COLOR_BLUE,
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.drawLine(
                        0,
                        (h * 0.65).toNumber(),
                        (w * 0.25).toNumber(),
                        (h * 0.65).toNumber()
                    );
                    dc.drawLine(
                        (w * 0.25).toNumber(),
                        (h * 0.65).toNumber(),
                        (w * 0.5).toNumber(),
                        (h * 0.8).toNumber()
                    );
                    dc.drawLine(
                        (w * 0.5).toNumber(),
                        (h * 0.8).toNumber(),
                        (w * 0.9).toNumber(),
                        (h * 0.6).toNumber()
                    );
                    dc.drawLine(
                        (w * 0.9).toNumber(),
                        (h * 0.6).toNumber(),
                        w,
                        (h * 0.75).toNumber()
                    );
                }
            }

            module _BackgroundMountain {
                function render(
                    dc as Graphics.Dc,
                    h as Number,
                    w as Number
                ) as Void {
                    dc.setColor(
                        Graphics.COLOR_DK_GRAY,
                        Graphics.COLOR_TRANSPARENT
                    );
                    dc.fillPolygon([
                        [0, h],
                        [(w * 0.1).toNumber(), (h * 0.55).toNumber()],
                        [(w * 0.4).toNumber(), (h * 0.7).toNumber()],
                        [(w * 0.8).toNumber(), (h * 0.45).toNumber()],
                        [w, (h * 0.6).toNumber()],
                        [w, h]
                    ]);
                }
            }
        }
    }
}
