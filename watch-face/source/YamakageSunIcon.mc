import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Math;

// Ported from Tomoo Ichimura's original YAMAKAGE Watch App
// shared/ui/SunIcon.mc (MIT). Keep this deliberately small and identical
// in visual proportions so the watch face follows the original design.
module YamakageSunIcon {
    function render(
        dc as Graphics.Dc,
        x as Number,
        y as Number
    ) as Void {
        renderScaled(dc, x, y, 7);
    }

    function renderScaled(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        radius as Number
    ) as Void {
        var r = radius;
        if (r < 5) { r = 5; }
        if (r > 14) { r = 14; }
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);

        dc.setPenWidth(1);
        var r1 = r + 2;
        var r2 = r + 9;
        for (var j = 0; j < 8; j++) {
            var angle = (j * Math.PI) / 4.0;
            dc.drawLine(
                x + (Math.cos(angle) * r1).toNumber(),
                y + (Math.sin(angle) * r1).toNumber(),
                x + (Math.cos(angle) * r2).toNumber(),
                y + (Math.sin(angle) * r2).toNumber()
            );
        }
    }
}
