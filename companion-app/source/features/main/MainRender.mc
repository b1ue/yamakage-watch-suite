import Toybox.Lang;
import Toybox.Graphics;

import Features.Main.Components.MainBackground;
import Features.Main.Components.MainClock;
import Features.Main.Components.MainGpsStatus;
import Features.Main.Components.MainTitle;
import Features.Main.Components.MainStartAction;
import Features.Main.Components.MainSunAnimation;
import Features.Main.Components.MainTargetSelector;

module Features {
    module Main {
        module MainRender {
            function render(dc as Graphics.Dc, props as Array) as Void {
                var w = props[MainProps.W] as Number;
                var h = props[MainProps.H] as Number;
                var cx = props[MainProps.CX] as Number;

                var titleFont =
                    props[MainProps.TITLE_FONT] as Graphics.FontType;
                var clockFont =
                    props[MainProps.CLOCK_FONT] as Graphics.FontType;
                var startBtnFont =
                    props[MainProps.START_BTN_FONT] as Graphics.FontType;
                var startBtnWidth = props[MainProps.START_BTN_WIDTH] as Number;
                var startBtnHeight =
                    props[MainProps.START_BTN_HEIGHT] as Number;

                var mode = props[MainProps.MODE] as Number;
                var isAnimOn = props[MainProps.IS_ANIM_ON] as Boolean;
                var progress = props[MainProps.PROGRESS] as Float;
                var sparkleBuffer = props[MainProps.SPARKLE_BUFFER] as Array?;

                var gpsText = props[MainProps.GPS_TEXT] as String;
                var gpsColor = props[MainProps.GPS_COLOR] as Graphics.ColorType;
                var isGpsReady = props[MainProps.IS_GPS_READY] as Boolean;
                var clockText = props[MainProps.CLOCK_TEXT] as String;
                var dateText = props[MainProps.DATE_TEXT] as String;
                var isTitleVisible =
                    props[MainProps.IS_TITLE_VISIBLE] as Boolean;

                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
                dc.clear();

                MainSunAnimation.render(
                    dc,
                    progress,
                    w,
                    h,
                    cx,
                    mode,
                    isAnimOn,
                    sparkleBuffer
                );
                MainBackground.render(dc, w, h, mode);

                var selectorX = (w * 0.85).toNumber();
                var selectorY = (h * 0.47).toNumber();
                MainTargetSelector.render(dc, selectorX, selectorY, mode);

                if (isTitleVisible) {
                    var titleY = (h * 0.065).toNumber();
                    MainTitle.render(dc, cx, titleY, titleFont, mode);
                }

                var clockY = (h * (isTitleVisible ? 0.19 : 0.12)).toNumber();
                MainClock.render(
                    dc,
                    cx,
                    clockY,
                    clockFont,
                    clockText,
                    dateText,
                    mode
                );

                var gpsY = (h * (isTitleVisible ? 0.34 : 0.28)).toNumber();
                MainGpsStatus.render(dc, cx, gpsY, gpsText, gpsColor);

                var btnY = (h * 0.8).toNumber();
                MainStartAction.render(
                    dc,
                    cx,
                    btnY,
                    startBtnWidth,
                    startBtnHeight,
                    startBtnFont,
                    isGpsReady,
                    mode
                );
            }
        }
    }
}
