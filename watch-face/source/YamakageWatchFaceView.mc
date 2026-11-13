import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Weather;

class YamakageWatchFaceView extends WatchUi.WatchFace {
    private var _sleeping as Boolean = false;
    private var _lastLocationProbe as Number = 0;
    private var _iconFont = null;
    private var _aodDotTiles = null;
    private var _aodDotLoadedMode as Number = -1;
    private var _skyDitherTiles = null;
    // In-memory rendering diagnostics: no storage writes from onUpdate.
    private var _terrainRenderStatus = null;
    private var _skyMarkerStatus = "SKY --";

    // Experimental features are deliberately lazy. Alpha 7.2 proved that the
    // base render path is stable, so neither weather nor DEM may run until
    // several successful onUpdate passes have already occurred.
    private var _featureTicks as Number = 0;
    private var _weatherProbeDone as Boolean = false;
    private var _demProbeDone as Boolean = false;

    // Per-frame terrain geometry cache. The renderer already computes these
    // masks; grid and seasonal passes reuse them instead of re-parsing and
    // re-sampling the same DEM multiple times per foreground refresh.
    private var _frameFrontMask = null;
    private var _frameRearMask = null;
    private var _frameMaskW as Number = -1;
    private var _frameMaskH as Number = -1;
    private var _frameMaskBaseY as Number = -1;
    private var _frameMaskShift as Number = 0;

    // Last scenic-body position lets weather be composed as one sky scene
    // instead of drawing unrelated cloud icons over the clock row.
    private var _lastSkyX as Number = -1;
    private var _lastSkyY as Number = -1;
    private var _lastSkyVisible as Boolean = false;
    private var _terrainRawCache = null;
    private var _terrainParsedCache = null;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        _iconFont = WatchUi.loadResource(Rez.Fonts.IconFont40) as Graphics.FontType;
        // Preload the selected mask before entering low-power display mode.
        _ensureAodDotTiles();
        _ensureSkyDitherTiles();
    }

    function onShow() as Void {
        _captureActivityLocation(true);
        _refreshLocalSunData(true);
        _featureTicks = 0;
        _weatherProbeDone = false;
        _demProbeDone = false;
    }

    function onEnterSleep() as Void {
        _sleeping = true;
    }

    function onExitSleep() as Void {
        _sleeping = false;
        _captureActivityLocation(true);
        _refreshLocalSunData(false);
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (!_sleeping) {
            _captureActivityLocation(false);
            _refreshLocalSunData(false);

            _featureTicks = _featureTicks + 1;
            if (_featureTicks >= 3 && !_weatherProbeDone) {
                _refreshWeatherLazy();
            }
            if (_featureTicks >= 6 && !_demProbeDone) {
                _demProbeDone = true;
            }
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setAntiAlias(true);

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        var now = Time.now().value();
        var sunrise = _activeSunrise();
        var sunset = _activeSunset();
        var isDay = _isDaytime(now, sunrise, sunset);

        if (_sleeping) {
            _renderSleep(dc, w, h, cx, isDay, sunrise, sunset);
        } else {
            _drawSkyBackground(dc, w, h, now, sunrise, sunset);
            _renderAwake(dc, w, h, cx, isDay, sunrise, sunset);
        }
    }

    private function _renderAwake(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        cx as Number,
        isDay as Boolean,
        sunrise,
        sunset
    ) as Void {
        var accent = isDay ? Graphics.COLOR_ORANGE : Graphics.COLOR_BLUE;
        var showBrand = _showYamakageLabel();
        var showColon = _showTimeColon();
        var showSeconds = _showSeconds();
        var weatherCondition = _weatherCondition();
        _lastSkyVisible = false;

        if (showBrand) {
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx,
                (h * 0.245).toNumber(),
                Graphics.FONT_SMALL,
                "YAMAKAGE",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // Reclaim the branding row when the label is hidden.
        var timeY = showBrand ? 0.385 : 0.340;
        var infoY = showBrand ? 0.515 : 0.480;
        var eventY = showBrand ? 0.610 : 0.580;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx,
            (h * timeY).toNumber(),
            Graphics.FONT_NUMBER_MEDIUM,
            FaceTime.clockText(showColon),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        if (showSeconds) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                (w * 0.835).toNumber(),
                (h * (showBrand ? 0.335 : 0.290)).toNumber(),
                Graphics.FONT_XTINY,
                FaceTime.secondsText(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx,
            (h * infoY).toNumber(),
            Graphics.FONT_XTINY,
            FaceTime.daylightRemainingText(sunrise, sunset) + " · " + FaceTime.dateText(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        _drawEventRow(dc, w, h, sunrise, sunset, accent, eventY);
        // Celestial marker is intentionally drawn BEFORE the terrain.
        // When the Sun/Moon reaches the gray/green silhouette at rise/set,
        // the terrain naturally occludes it instead of the icon floating on
        // top of the ridge. The outer-rim portion remains visible in the sky.
        _drawSkyMarker(dc, w, h, isDay, accent, sunrise, sunset);
        _drawWeatherAtmosphere(dc, w, h, isDay, weatherCondition);
        _drawMountains(dc, w, h, isDay, false, 0, weatherCondition);
        _drawHorizonIllumination(dc, w, h, isDay);
        if (_gridOverlay()) {
            _drawGridOverlay(dc, w, h, false, 0);
        }
        // Seasonal vegetation/snow sits on top of the ground terrain and its
        // survey grid, so the tiny accents remain readable without floating.
        _drawSeasonalDetails(dc, w, h, isDay, false, 0);
        if (_showStatusLine()) {
            _drawLocationStatus(dc, w, h, accent);
        }
    }

    private function _renderSleep(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        cx as Number,
        isDay as Boolean,
        sunrise,
        sunset
    ) as Void {
        // AOD clock/terrain stay at fixed coordinates. Only the black-dot
        // occlusion mask changes phase once per normal minute refresh.
        var shift = 0;
        var showBrand = _showYamakageLabel();
        var showColon = _showTimeColon();
        var level = _aodDimLevel();

        // Each brightness level affects *all* persistent elements, including
        // the real DEM outlines. Lower RGB values reduce lit pixel intensity.
        var clockColor = Graphics.COLOR_LT_GRAY;
        var detailColor = Graphics.COLOR_DK_GRAY;
        if (level == 1) {
            clockColor = Graphics.createColor(255, 85, 85, 85);
            detailColor = Graphics.createColor(255, 58, 58, 58);
        } else if (level == 2) {
            clockColor = Graphics.createColor(255, 53, 56, 54);
            detailColor = Graphics.createColor(255, 34, 36, 34);
        } else if (level >= 3) {
            clockColor = Graphics.createColor(255, 29, 31, 30);
            detailColor = Graphics.createColor(255, 18, 20, 19);
        }

        dc.setColor(clockColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx + shift,
            (h * 0.37).toNumber(),
            Graphics.FONT_NUMBER_MILD,
            FaceTime.clockText(showColon),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(detailColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx - shift,
            (h * 0.49).toNumber(),
            Graphics.FONT_XTINY,
            (showBrand ? "YAMAKAGE  " : "") + FaceTime.dateText(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Give the original YAMAKAGE glyphs their own row in AOD. Keeping the
        // icons above the numbers avoids the cramped icon+time collision seen
        // on the physical 51 mm AMOLED display.
        var riseX = (w * 0.33).toNumber();
        var setX = (w * 0.67).toNumber();
        var iconY = (h * 0.585).toNumber();
        var timeY = (h * 0.645).toNumber();
        if (_iconFont != null) {
            dc.setColor(detailColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                riseX + shift,
                iconY,
                _iconFont as Graphics.FontType,
                FaceIcons.SUNRISE,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.drawText(
                setX - shift,
                iconY,
                _iconFont as Graphics.FontType,
                FaceIcons.SUNSET,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
        dc.setColor(detailColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            riseX - shift,
            timeY,
            Graphics.FONT_XTINY,
            FaceTime.eventText(sunrise),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            setX + shift,
            timeY,
            Graphics.FONT_XTINY,
            FaceTime.eventText(sunset),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        _drawMountains(dc, w, h, isDay, true, shift, null);
        // AOD grid is separately opt-in because static intersecting lines
        // consume pixels and can be distracting at night.
        if (_gridOverlay() && _gridInAod()) {
            _drawGridOverlay(dc, w, h, true, shift);
        }
        // DRAW LAST: black pixels occlude a shifting subset of already-drawn
        // glyph and ridge pixels; clear pixels in the PNG do nothing.
        _drawAodDotMask(dc, w, h);
    }

    // A fixed 180 degree panorama: east on the left, west on the right.
    // Northern hemisphere faces south; southern hemisphere faces north.
    // Holding it fixed prevents the mountains from sliding as the Sun moves.
    private function _horizonCenterAz() as Double {
        var lat = Application.Storage.getValue(FaceKeys.LAT);
        if (lat != null && lat.toDouble() < 0.0) {
            return (0).toDouble();
        }
        return (180).toDouble();
    }

    private function _horizonSense() as Double {
        var lat = Application.Storage.getValue(FaceKeys.LAT);
        if (lat != null && lat.toDouble() < 0.0) {
            return (-1).toDouble();
        }
        return (1).toDouble();
    }

    private function _wrap360(angle as Double) as Double {
        var a = angle;
        while (a < 0.0) { a += 360.0; }
        while (a >= 360.0) { a -= 360.0; }
        return a;
    }

    private function _wrap180(angle as Double) as Double {
        var a = _wrap360(angle);
        if (a > 180.0) { a -= 360.0; }
        return a;
    }

    private function _azForFraction(fraction as Double) as Double {
        return _wrap360(
            _horizonCenterAz() +
            (fraction - 0.5) * _terrainAzSpan() * _horizonSense()
        );
    }

    private function _terrainDetailMode() as Number {
        try {
            var value = Application.Properties.getValue(FaceKeys.TERRAIN_DETAIL);
            if (value instanceof Number) {
                var mode = value as Number;
                if (mode >= 0 && mode <= 3) { return mode; }
            }
        } catch (e) {}
        return 1;
    }

    private function _terrainAzSpan() as Double {
        var mode = _terrainDetailMode();
        if (mode == 0) { return (180).toDouble(); }
        if (mode == 2) { return (120).toDouble(); }
        if (mode >= 3) { return (96).toDouble(); }
        return (150).toDouble();
    }

    private function _terrainVerticalScale() as Double {
        var mode = _terrainDetailMode();
        if (mode == 0) { return (1).toDouble(); }
        if (mode == 2) { return (135).toDouble() / (100).toDouble(); }
        if (mode >= 3) { return (165).toDouble() / (100).toDouble(); }
        return (115).toDouble() / (100).toDouble();
    }

    private function _terrainProfile() {
        try {
            var raw = getApp().getTerrainPacket();
            if (raw == null || !(raw instanceof String)) { return null; }
            var rawString = raw as String;
            if (_terrainRawCache != null &&
                (_terrainRawCache as String).equals(rawString) &&
                _terrainParsedCache != null) {
                return _terrainParsedCache;
            }
            var parsed = CompanionPayload.parseTerrain(rawString);
            _terrainRawCache = rawString;
            _terrainParsedCache = parsed;
            return parsed;
        } catch (e) {
            return null;
        }
    }

    // Nearest-neighbour sampling is deliberate: identical to the proven
    // alpha 7.6.10 front-ridge renderer and avoids fractional Array indices.
    private function _terrainAngleAtAz(profile as Array, az as Double) as Double? {
        if (profile.size() < 2 || !(profile[1] instanceof Array)) {
            return null;
        }
        var step = profile[0];
        var values = profile[1] as Array;
        if (step == null || values.size() < 3 || step.toDouble() <= 0.0) {
            return null;
        }
        var rounded = Math.round(_wrap360(az) / step.toDouble());
        var idx = rounded.toNumber() % values.size();
        if (idx < 0) { idx += values.size(); }
        var raw = values[idx];
        if (raw == null) { return null; }
        var angle = raw.toDouble() / 10.0;
        if (angle < -5.0) { angle = -5.0; }
        if (angle > 45.0) { angle = 45.0; }
        return angle;
    }


    // Returns the Y coordinate of the gray/rear terrain contour at a screen
    // fraction. It mirrors the renderer's 3-point smoothing and rear lift so
    // the perimeter Sun/Moon can literally rise from and set into that ridge.
    private function _rearTerrainYAtFraction(
        profile as Array,
        fraction as Double,
        h as Number
    ) as Number? {
        var f = fraction;
        if (f < 0.0) { f = 0.0; }
        if (f > 1.0) { f = 1.0; }

        var delta = (1).toDouble() / (12).toDouble();
        var beforeF = f - delta;
        var afterF = f + delta;
        if (beforeF < 0.0) { beforeF = 0.0; }
        if (afterF > 1.0) { afterF = 1.0; }

        var centerA = _terrainAngleAtAz(profile, _azForFraction(f));
        if (centerA == null) { return null; }
        var beforeA = _terrainAngleAtAz(profile, _azForFraction(beforeF));
        var afterA = _terrainAngleAtAz(profile, _azForFraction(afterF));
        if (beforeA == null) { beforeA = centerA; }
        if (afterA == null) { afterA = centerA; }

        var horizonY = h * 0.77;
        var verticalRange = h * 0.19 * _terrainVerticalScale();
        var y0 = horizonY - (beforeA.toDouble() / 45.0) * verticalRange;
        var y1 = horizonY - (centerA.toDouble() / 45.0) * verticalRange;
        var y2 = horizonY - (afterA.toDouble() / 45.0) * verticalRange;
        var smoothed = (y0 + 2.0 * y1 + y2) / 4.0;
        var rearLift = h * (0.048 + 0.008 * (_terrainVerticalScale() - 1.0));
        var rearY = smoothed - rearLift;
        if (rearY < 0.0) { rearY = 0.0; }
        if (rearY > h - 1) { rearY = (h - 1).toDouble(); }
        return rearY.toNumber();
    }

    // The scenic path is a time-compressed daylight/nighttime arc, not a
    // literal 180-degree azimuth plot of the Moon. Horizontal travel follows
    // rise -> peak -> set; the vertical baseline is sampled from our cached
    // terrain at the marker's screen position. Moon phase still uses the
    // locally calculated ephemeris when coordinates are available.
    // This deliberate projection keeps the bodies visible in our narrow
    // scenery window and does not purport to show accurate lunar rise times.
    private function _scenicTravelFraction(
        now,
        isDay as Boolean,
        sunrise,
        sunset
    ) as Double {
        var progress = (0.5).toDouble();
        if (
            sunrise != null && sunset != null &&
            (sunrise instanceof Number || sunrise instanceof Long) &&
            (sunset instanceof Number || sunset instanceof Long) &&
            sunset.toNumber() > sunrise.toNumber()
        ) {
            var rise = sunrise.toNumber();
            var set = sunset.toNumber();
            if (isDay) {
                progress = (now - rise).toDouble() /
                    (set - rise).toDouble();
            } else {
                var nightStart = set;
                var nightEnd = rise + 86400;
                if (now < rise) {
                    nightStart = set - 86400;
                    nightEnd = rise;
                }
                if (nightEnd > nightStart) {
                    progress = (now - nightStart).toDouble() /
                        (nightEnd - nightStart).toDouble();
                }
            }
        } else {
            // Useful even on first install before Garmin provides events.
            var info = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var hours = info.hour.toDouble() + info.min.toDouble() / 60.0;
            if (isDay) {
                progress = (hours - 6.0) / 12.0;
            } else if (hours < 6.0) {
                progress = (hours + 6.0) / 12.0;
            } else {
                progress = (hours - 18.0) / 12.0;
            }
        }
        if (progress < 0.0) { progress = 0.0; }
        if (progress > 1.0) { progress = 1.0; }
        return progress.toDouble();
    }

    private function _drawSkyMarker(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        isDay as Boolean,
        accent as Graphics.ColorType,
        sunrise,
        sunset
    ) as Void {
        _skyMarkerStatus = "SKY --";
        try {
            var pathMode = _celestialPath();
            if (pathMode == 2) {
                _skyMarkerStatus = "SKY OFF";
                return;
            }
            var progress = _scenicTravelFraction(
                Time.now().value(), isDay, sunrise, sunset
            );
            // Mode 1: travel along the *inside* of the upper circular bezel.
            // The outer arc uses a 130-degree sweep (155° -> 25°) so the
            // icon never clips the round 454px display. Near the rim, the
            // main clock and event row remain completely untouched.
            // We do not draw a static path, minimizing persistent OLED lines.
            var x = 0;
            var y = 0;
            if (pathMode == 1) {
                // TRUE perimeter mode.  Most of the transit is constrained to
                // an outer annulus just inside the round bezel, matching the
                // reference watch-face behavior.  Only the first/last 8% blend
                // down to the gray/rear terrain so rise and set still emerge
                // from the actual terrain silhouette.
                var startF = (7).toDouble() / (100).toDouble();
                var endF = (93).toDouble() / (100).toDouble();

                var leftY = (h * 0.66).toNumber();
                var rightY = (h * 0.66).toNumber();
                var rimProfile = _terrainProfile();
                if (rimProfile != null) {
                    var ly = _rearTerrainYAtFraction(rimProfile, startF, h);
                    var ry = _rearTerrainYAtFraction(rimProfile, endF, h);
                    if (ly != null) { leftY = ly; }
                    if (ry != null) { rightY = ry; }
                }

                // Outer annulus: 166° at the left through 90° at the top to
                // 14° on the right.  A slight upward center bias keeps the icon
                // clear of the YAMAKAGE label and large time digits.
                var thetaDeg = 166.0 - 152.0 * progress;
                var theta = thetaDeg * Math.PI / 180.0;
                var diameter = w;
                if (h < w) { diameter = h; }
                var radius = diameter * 0.435;
                var rimCx = w / 2.0;
                var rimCy = h * 0.505;
                var rimX = rimCx + radius * Math.cos(theta);
                var rimY = rimCy - radius * Math.sin(theta);

                var terrainX = rimX;
                var terrainY = rimY;
                var blend = 1.0;
                var edgePortion = 0.08;

                if (progress < edgePortion) {
                    var tIn = progress / edgePortion;
                    tIn = tIn * tIn * (3.0 - 2.0 * tIn);
                    terrainX = startF * (w - 1);
                    terrainY = leftY.toDouble();
                    blend = tIn;
                } else if (progress > (1.0 - edgePortion)) {
                    var tOut = (1.0 - progress) / edgePortion;
                    tOut = tOut * tOut * (3.0 - 2.0 * tOut);
                    terrainX = endF * (w - 1);
                    terrainY = rightY.toDouble();
                    blend = tOut;
                }

                var cxRim = terrainX * (1.0 - blend) + rimX * blend;
                var cyRim = terrainY * (1.0 - blend) + rimY * blend;

                // Final hard guard: except during the terrain-join segment,
                // perimeter mode may never enter the central clock/data block.
                if (progress >= edgePortion && progress <= (1.0 - edgePortion)) {
                    var maxRimY = h * 0.315;
                    if (cyRim > maxRimY) { cyRim = maxRimY; }
                }

                if (cxRim < w * 0.035) { cxRim = w * 0.035; }
                if (cxRim > w * 0.965) { cxRim = w * 0.965; }
                if (cyRim < h * 0.045) { cyRim = h * 0.045; }
                if (cyRim > h * 0.79) { cyRim = h * 0.79; }
                x = cxRim.toNumber();
                y = cyRim.toNumber();
            } else {
                // Mode 0: existing landscape track. The marker is tied to
                // the actual DEM ridge beneath the sunrise/event data.
                // This intentionally preserves alpha 7.6.11.3 behavior.
                var fractionX = 0.16 + progress * 0.68;
                x = (fractionX * (w - 1)).toNumber();

                var terrainAngle = (0).toDouble();
                var profile = _terrainProfile();
                if (profile != null) {
                    var sampledAngle = _terrainAngleAtAz(
                        profile, _azForFraction(fractionX.toDouble())
                    );
                    if (sampledAngle != null) {
                        terrainAngle = sampledAngle.toDouble();
                    }
                }
                var ridgeY = h * 0.77 -
                    (terrainAngle / 45.0) * (h * 0.19) - h * 0.055;
                var arc = Math.sin(Math.PI * progress);
                if (arc < 0.0) { arc = 0.0; }
                var lift = 8.0 + arc * (h * 0.055);
                var cy = ridgeY - lift;
                if (cy < h * 0.59) { cy = h * 0.59; }
                if (cy > h * 0.79) { cy = h * 0.79; }
                y = cy.toNumber();
            }

            var largeBody = _largeCelestial();
            if (largeBody && pathMode == 1) {
                var edgeX = (w * 0.055).toNumber();
                var edgeY = (h * 0.055).toNumber();
                if (x < edgeX) { x = edgeX; }
                if (x > w - edgeX) { x = w - edgeX; }
                if (y < edgeY) { y = edgeY; }
            }
            _lastSkyX = x;
            _lastSkyY = y;
            _lastSkyVisible = true;

            if (isDay) {
                if (largeBody) {
                    YamakageSunIcon.renderScaled(dc, x, y, 11);
                } else {
                    YamakageSunIcon.render(dc, x, y);
                }
                _skyMarkerStatus = pathMode == 1 ? "SUN RIM" : "SUN LAND";
            } else {
                var fraction = 0.25f;
                var phase = 0.25f;
                // The Moon follows an illustrative nighttime arc, but its
                // illuminated fraction and waxing/waning geometry are real
                // approximations from the current location and timestamp.
                try {
                    var lat = Application.Storage.getValue(FaceKeys.LAT);
                    var lon = Application.Storage.getValue(FaceKeys.LON);
                    if (lat != null && lon != null) {
                        var lunar = MoonPosition.calculate(
                            lat.toDouble(), lon.toDouble(), Time.now().value()
                        );
                        if (lunar != null && lunar.size() >= 4) {
                            phase = lunar[2].toFloat();
                            fraction = lunar[3].toFloat();
                        }
                    }
                    if (_enhancedDataFresh()) {
                        var sf = Application.Storage.getValue(FaceKeys.MOON_FRACTION);
                        var sp = Application.Storage.getValue(FaceKeys.MOON_PHASE);
                        if (sf != null && sp != null) {
                            fraction = sf.toFloat();
                            phase = sp.toFloat();
                        }
                    }
                } catch (ephemerisError) {
                    // Retain the original Watch App's quarter-Moon default.
                }
                if (fraction < 0.0f) { fraction = 0.0f; }
                if (fraction > 1.0f) { fraction = 1.0f; }
                if (phase < 0.0f) { phase = 0.0f; }
                if (phase > 1.0f) { phase = 1.0f; }
                YamakageMoonIcon.render(dc, x, y, fraction, phase, largeBody ? 15 : 10);
                _skyMarkerStatus = pathMode == 1 ? "MOON RIM" : "MOON LAND";
            }
        } catch (e) {
            // Decorative sky must never crash time/terrain. The status shows
            // where the pipeline ended on the *current* foreground frame.
            _skyMarkerStatus = "SKY ERR";
        }
    }

    private function _drawHorizonIllumination(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        isDay as Boolean
    ) as Void {
        if (!isDay || !_horizonGlow()) { return; }
        try {
            var profile = _terrainProfile();
            if (profile == null) { return; }

            // A very restrained copper-gold 1px rim along the real DEM crest.
            // This is a static/daylight effect, not a battery-intensive glow
            // bitmap or full-bright flood fill.
            dc.setPenWidth(1);
            dc.setColor(Graphics.createColor(255, 117, 85, 44),
                Graphics.COLOR_TRANSPARENT);
            var lastX = -1;
            var lastY = -1;
            // Match exactly the 13 ridge vertices used by the renderer.
            for (var i = 0; i <= 12; i++) {
                var f = i.toDouble() / 12.0;
                var ang = _terrainAngleAtAz(profile, _azForFraction(f));
                if (ang == null) { continue; }
                var x = (f * (w - 1)).toNumber();
                var y = (h * 0.77 - (ang.toDouble() / 45.0) *
                    (h * 0.19)).toNumber();
                if (lastX >= 0) {
                    dc.drawLine(lastX, lastY, x, y);
                }
                lastX = x;
                lastY = y;
            }
        } catch (e) {
            // Illumination is purely decorative; the DEM/clock still work.
        }
    }

    private function _drawEventRow(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        sunrise,
        sunset,
        accent as Graphics.ColorType,
        yRatio
    ) as Void {
        var y = (h * yRatio).toNumber();
        // Keep each original YAMAKAGE glyph and its time in its own fixed
        // column. Explicit coordinates prevent the icon/time overlap seen on
        // the physical 51 mm display.
        var riseIconX = (w * 0.265).toNumber();
        var riseTimeX = (w * 0.395).toNumber();
        var setIconX = (w * 0.585).toNumber();
        var setTimeX = (w * 0.715).toNumber();

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.245).toNumber(), y - 28, (w * 0.755).toNumber(), y - 28);

        // Use the original YAMAKAGE sunrise/sunset icon glyphs. The icons
        // communicate rise/set on their own, which buys back enough width to
        // keep the event times comfortably separated on a round display.
        if (_iconFont != null) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                riseIconX,
                y,
                _iconFont as Graphics.FontType,
                FaceIcons.SUNRISE,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.setColor(Graphics.COLOR_PURPLE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                setIconX,
                y,
                _iconFont as Graphics.FontType,
                FaceIcons.SUNSET,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            riseTimeX,
            y,
            Graphics.FONT_XTINY,
            FaceTime.eventText(sunrise),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            setTimeX,
            y,
            Graphics.FONT_XTINY,
            FaceTime.eventText(sunset),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function _drawMountains(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        isDay as Boolean,
        sleepMode as Boolean,
        shift as Number,
        weatherCondition
    ) as Void {
        var baseY = sleepMode
            ? (h * 0.84).toNumber()
            : (_showStatusLine() ? (h * 0.835).toNumber() : h - 1);

        // Every active draw must explicitly report its own rendering state.
        // Do not display a stale receiver flag as evidence that drawing is
        // still pending; foreground terrain drawing is synchronous.
        // Active and AOD use the exact same received/cached 360-degree
        // horizon. Only the *rendering style* changes for low-power AMOLED.
        // getTerrainPacket() falls back to Application.Storage after a restart.
        _terrainRenderStatus = "TRN NONE";
        try {
            var profile = _terrainProfile();
            if (profile != null) {
                if (_drawTerrainProfile(
                    dc, w, h, baseY, isDay, sleepMode, shift,
                    weatherCondition, profile
                )) {
                    _terrainRenderStatus = "TRN DRAW";
                    return;
                }
                _terrainRenderStatus = "TRN BAD";
            }
        } catch (e) {
            // The profile or graphics routine should never crash the face.
            // Leave the last drawing stage visible on the active status line.
            _terrainRenderStatus = "E " + (_terrainRenderStatus as String);
        }

        var p1 = [
            [0, baseY],
            [(w * 0.10).toNumber(), (h * 0.685).toNumber()],
            [(w * 0.40).toNumber(), (h * 0.755).toNumber()],
            [(w * 0.80).toNumber(), (h * 0.645).toNumber()],
            [w, (h * 0.715).toNumber()],
            [w, baseY]
        ];
        var p2 = [
            [0, baseY],
            [(w * 0.25).toNumber(), (h * 0.74).toNumber()],
            [(w * 0.50).toNumber(), (h * 0.815).toNumber()],
            [(w * 0.90).toNumber(), (h * 0.70).toNumber()],
            [w, (h * 0.765).toNumber()],
            [w, baseY]
        ];

        _cacheFallbackTerrainMasks(p1, p2, w, h, baseY, shift);

        if (sleepMode) {
            dc.setPenWidth(1);
            var fallbackTone = Graphics.COLOR_DK_GRAY;
            var dim = _aodDimLevel();
            if (dim == 1) {
                fallbackTone = Graphics.createColor(255, 50, 54, 50);
            } else if (dim == 2) {
                fallbackTone = Graphics.createColor(255, 30, 34, 30);
            } else if (dim >= 3) {
                fallbackTone = Graphics.createColor(255, 18, 21, 18);
            }
            dc.setColor(fallbackTone, Graphics.COLOR_TRANSPARENT);
            for (var i = 1; i < p1.size() - 1; i++) {
                dc.drawLine(
                    p1[i - 1][0] + shift,
                    p1[i - 1][1],
                    p1[i][0] + shift,
                    p1[i][1]
                );
            }
            return;
        }

        dc.setColor(isDay ? Graphics.createColor(255, 66, 65, 55)
                : Graphics.createColor(255, 29, 34, 34),
            Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(p1);
        dc.setColor(
            _terrainColor(isDay, weatherCondition),
            Graphics.COLOR_TRANSPARENT
        );
        dc.fillPolygon(p2);
    }

    private function _drawSkyBackground(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        now as Number,
        sunrise,
        sunset
    ) as Void {
        var mode = _skyBackgroundMode();
        if (mode <= 0) { return; }

        var phase = _skyPhase(now, sunrise, sunset);
        // Mode 1 keeps the original black night. Mode 3 is the inverse scenic
        // option: solid black through daylight/twilight, colored night only.
        if (mode == 1 && phase == 0) { return; }
        if (mode == 3 && phase != 0) { return; }

        var brightness = _skyBrightness();
        var skyColor = Graphics.createColor(255, 7, 13, 21);
        if (brightness == 0) {
            if (phase == 2) { skyColor = Graphics.createColor(255, 52, 96, 136); }
            else if (phase == 1) { skyColor = Graphics.createColor(255, 70, 77, 101); }
            else if (phase == 3) { skyColor = Graphics.createColor(255, 78, 56, 83); }
            else { skyColor = Graphics.createColor(255, 11, 22, 38); }
        } else if (brightness >= 2) {
            if (phase == 2) { skyColor = Graphics.createColor(255, 22, 45, 66); }
            else if (phase == 1) { skyColor = Graphics.createColor(255, 32, 38, 52); }
            else if (phase == 3) { skyColor = Graphics.createColor(255, 38, 29, 43); }
            else { skyColor = Graphics.createColor(255, 5, 10, 18); }
        } else {
            if (phase == 2) { skyColor = Graphics.createColor(255, 34, 70, 102); }
            else if (phase == 1) { skyColor = Graphics.createColor(255, 47, 58, 78); }
            else if (phase == 3) { skyColor = Graphics.createColor(255, 55, 43, 62); }
            else { skyColor = Graphics.createColor(255, 7, 13, 21); }
        }

        dc.setColor(skyColor, skyColor);
        dc.fillRectangle(0, 0, w, h);

        var dither = _skyDitherMode();
        if (dither > 0) {
            _drawSkyDither(dc, w, h, dither);
        } else if (_skyDimGrid()) {
            // Preserve old installs that had the previous boolean enabled.
            _drawSkyDither(dc, w, h, 3);
        }
    }

    private function _skyPhase(
        now as Number,
        sunrise,
        sunset
    ) as Number {
        if (!(sunrise instanceof Number || sunrise instanceof Long) ||
            !(sunset instanceof Number || sunset instanceof Long)) {
            return 0;
        }
        var rise = sunrise.toNumber();
        var set = sunset.toNumber();
        // Civil-ish scenic twilight window: 45 minutes on either side.
        var twilight = 2700;
        if (now >= rise && now <= set) {
            if (now - rise <= twilight) { return 1; }
            if (set - now <= twilight) { return 3; }
            return 2;
        }
        if (now < rise && rise - now <= twilight) { return 1; }
        if (now > set && now - set <= twilight) { return 3; }
        return 0;
    }

    private function _drawSkyDither(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        mode as Number
    ) as Void {
        // Modes 1-4 preserve the original technical line grids. Modes 5-7
        // use the same opaque-black/transparent micro masks proven in AOD,
        // which creates the tiny ordered-dither look that photographs oddly
        // but reads beautifully on the AMOLED panel.
        if (mode >= 5) {
            _ensureSkyDitherTiles();
            if (_skyDitherTiles == null) { return; }
            try {
                var tiles = _skyDitherTiles as Array;
                var idx = mode - 5;
                if (idx < 0) { idx = 0; }
                if (idx >= tiles.size()) { idx = tiles.size() - 1; }
                var mask = tiles[idx];
                if (mask == null) { return; }
                var tx = 0;
                while (tx < w) {
                    var ty = 0;
                    while (ty < h) {
                        dc.drawBitmap(tx, ty, mask);
                        ty += 60;
                    }
                    tx += 60;
                }
            } catch (e) {}
            return;
        }

        var step = 18;
        if (mode == 1) { step = 8; }
        else if (mode == 2) { step = 12; }
        else if (mode == 3) { step = 18; }
        else if (mode >= 4) { step = 26; }

        dc.setPenWidth(1);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var x = 0;
        while (x < w) {
            dc.drawLine(x, 0, x, h - 1);
            x += step;
        }
        var y = 0;
        while (y < h) {
            dc.drawLine(0, y, w - 1, y);
            y += step;
        }
    }

    private function _ensureSkyDitherTiles() as Void {
        if (_skyDitherTiles != null) { return; }
        try {
            _skyDitherTiles = [
                WatchUi.loadResource(Rez.Drawables.AodDotsSparse0),
                WatchUi.loadResource(Rez.Drawables.AodDotsBalanced0),
                WatchUi.loadResource(Rez.Drawables.AodDotsStrong0)
            ];
        } catch (e) {
            _skyDitherTiles = null;
        }
    }

    private function _drawLocationStatus(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        accent as Graphics.ColorType
    ) as Void {
        var locTime = Application.Storage.getValue(FaceKeys.LOC_TIME);
        var hasLocation = locTime != null;
        var cx = w / 2;

        if (hasLocation) {
            // Distinct version marker confirms the new two-layer build.
            // The rendering result takes priority over all prior RX/DEM flags.
            var status = "9.7 · " + (_terrainRenderStatus as String) +
                " · " + _skyMarkerStatus;

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx,
                (h * 0.872).toNumber(),
                Graphics.FONT_XTINY,
                status,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        } else {
            // Protect the first-run / no-location instructions from the
            // mountain fill. A compact black band keeps the fallback state
            // crisp and readable on the round 454 px display.
            var bandTop = (h * 0.805).toNumber();
            var bandHeight = (h * 0.145).toNumber();
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.fillRectangle(
                (w * 0.16).toNumber(),
                bandTop,
                (w * 0.68).toNumber(),
                bandHeight
            );

            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx,
                (h * 0.845).toNumber(),
                Graphics.FONT_XTINY,
                "START GPS ACTIVITY",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx,
                (h * 0.895).toNumber(),
                Graphics.FONT_XTINY,
                "RETURN AFTER GPS LOCK",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }


    private function _drawTerrainProfile(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        baseY as Number,
        isDay as Boolean,
        sleepMode as Boolean,
        shift as Number,
        weatherCondition,
        profile as Array
    ) as Boolean {
        _terrainRenderStatus = "HEADER";
        if (
            profile.size() < 2 ||
            !(profile[0] instanceof Number) ||
            !(profile[1] instanceof Array)
        ) {
            return false;
        }

        var step = profile[0] as Number;
        var values = profile[1] as Array;
        if (step <= 0 || values.size() < 3) {
            return false;
        }

        // Fixed south-facing (north in southern hemisphere) panorama.
        // The Sun/Moon screen X is projected against this exact same DEM.
        _terrainRenderStatus = "AZ";
        var centerAz = _horizonCenterAz();
        var sense = _horizonSense();

        // Separate integer coordinate arrays remove the dynamic nested-array
        // cast and let us bound every draw operation to the visible DC.
        _terrainRenderStatus = "SAMPLE";
        var ridgeX = [] as Array<Number>;
        var ridgeY = [] as Array<Number>;
        var sampleCount = 13;
        var horizonY = (h * 0.77).toNumber();
        var verticalRange = h * 0.19 * _terrainVerticalScale();
        var azSpan = _terrainAzSpan();

        for (var i = 0; i < sampleCount; i++) {
            var frac = i.toDouble() / (sampleCount - 1).toDouble();
            var az = centerAz + (frac - 0.5) * azSpan * sense;
            while (az < 0.0) { az += 360.0; }
            while (az >= 360.0) { az -= 360.0; }

            // Math.round() PRESERVES the input's numeric type in Monkey C.
            // A Double index raises a runtime exception when indexing Array.
            var indexRounded = Math.round(az / step.toDouble());
            var idx = indexRounded.toNumber() % values.size();
            if (idx < 0) { idx += values.size(); }

            var sample = values[idx];
            if (
                sample == null ||
                !(sample instanceof Number || sample instanceof Long ||
                  sample instanceof Float || sample instanceof Double)
            ) {
                return false;
            }

            var angle = sample.toDouble() / 10.0;
            if (angle < -5.0) { angle = -5.0; }
            if (angle > 45.0) { angle = 45.0; }

            var x = (frac * (w - 1)).toNumber() + shift;
            if (x < 0) { x = 0; }
            if (x >= w) { x = w - 1; }
            var y = (horizonY - (angle / 45.0) * verticalRange).toNumber();
            if (y < 0) { y = 0; }
            if (y >= h) { y = h - 1; }

            ridgeX.add(x);
            ridgeY.add(y);
        }

        if (ridgeX.size() < 2) {
            return false;
        }

        // Both terrain layers derive from the same sampled DEM horizon.
        // The gray/rear range is smoothed + lifted for visual depth, not a
        // separate physical mountain ridge. Shared by active and AOD paths.
        _terrainRenderStatus = "REAR";
        var rearY = [] as Array<Number>;
        var rearLift = (h * (0.048 + 0.008 * (_terrainVerticalScale() - 1.0))).toNumber();
        var ridgeSize = ridgeY.size();
        for (var ri = 0; ri < ridgeSize; ri++) {
            var before = ridgeY[ri == 0 ? 0 : ri - 1];
            var after = ridgeY[ri + 1 < ridgeSize ? ri + 1 : ri];
            var smoothed = (
                (before + 2 * ridgeY[ri] + after) / 4.0
            ).toNumber();
            var rearTop = smoothed - rearLift;
            if (rearTop < 0) { rearTop = 0; }
            if (rearTop > baseY) { rearTop = baseY; }
            rearY.add(rearTop);
        }

        _cacheTerrainMasks(ridgeX, ridgeY, rearY, w, h, baseY, shift);

        if (sleepMode) {
            // Two terrain-derived AOD contours; dim strength affects both.
            // Ultra dim hides the rear outline completely to reduce pixels.
            var aodLevel = _aodDimLevel();
            var rearTone = Graphics.createColor(255, 33, 38, 35);
            var frontTone = Graphics.createColor(255, 76, 82, 74);
            if (aodLevel == 1) {
                rearTone = Graphics.createColor(255, 26, 30, 27);
                frontTone = Graphics.createColor(255, 54, 60, 53);
            } else if (aodLevel == 2) {
                rearTone = Graphics.createColor(255, 17, 20, 18);
                frontTone = Graphics.createColor(255, 35, 39, 34);
            } else if (aodLevel >= 3) {
                rearTone = Graphics.createColor(255, 8, 10, 9);
                frontTone = Graphics.createColor(255, 21, 24, 21);
            }
            _terrainRenderStatus = "AOD REAR";
            dc.setPenWidth(1);
            dc.setColor(rearTone, Graphics.COLOR_TRANSPARENT);
            if (aodLevel < 3) {
                for (var ar = 1; ar < ridgeX.size(); ar++) {
                    dc.drawLine(
                        ridgeX[ar - 1], rearY[ar - 1],
                        ridgeX[ar], rearY[ar]
                    );
                }
            }

            _terrainRenderStatus = "AOD FRONT";
            dc.setColor(frontTone, Graphics.COLOR_TRANSPARENT);
            for (var af = 1; af < ridgeX.size(); af++) {
                dc.drawLine(
                    ridgeX[af - 1], ridgeY[af - 1],
                    ridgeX[af], ridgeY[af]
                );
            }
            return true;
        }

        // Rear ridge: misty stone by day, charcoal rock by night.
        dc.setColor(isDay ? Graphics.createColor(255, 66, 65, 55)
                : Graphics.createColor(255, 29, 34, 34),
            Graphics.COLOR_TRANSPARENT);
        var rearStripWidth = 4;
        for (var rk = 1; rk < ridgeX.size(); rk++) {
            var rx1 = ridgeX[rk - 1];
            var rx2 = ridgeX[rk];
            var ry1 = rearY[rk - 1];
            var ry2 = rearY[rk];
            var rearSegmentWidth = rx2 - rx1;
            if (rearSegmentWidth <= 0) { continue; }

            for (var rx = rx1; rx < rx2; rx += rearStripWidth) {
                var t = (rx - rx1).toFloat() /
                    rearSegmentWidth.toFloat();
                var top = (ry1 + (ry2 - ry1) * t).toNumber();
                if (top < 0) { top = 0; }
                if (top > baseY) { top = baseY; }
                var runWidth = rearStripWidth;
                if (rx + runWidth > rx2) { runWidth = rx2 - rx; }
                if (rx + runWidth > w) { runWidth = w - rx; }
                var runHeight = baseY - top;
                if (runWidth > 0 && runHeight > 0 && rx >= 0) {
                    dc.fillRectangle(rx, top, runWidth, runHeight);
                }
            }
        }

        // Keep the proven foreground blue/green drawing loop unchanged.
        _terrainRenderStatus = "FILL";
        dc.setColor(
            _terrainColor(isDay, weatherCondition),
            Graphics.COLOR_TRANSPARENT
        );
        var stripWidth = 4;
        for (var k = 1; k < ridgeX.size(); k++) {
            var x1 = ridgeX[k - 1];
            var y1 = ridgeY[k - 1];
            var x2 = ridgeX[k];
            var y2 = ridgeY[k];

            var segmentWidth = x2 - x1;
            if (segmentWidth <= 0) {
                continue;
            }

            for (var sx = x1; sx < x2; sx += stripWidth) {
                var fraction = (sx - x1).toFloat() /
                    segmentWidth.toFloat();
                var topY = (y1 + (y2 - y1) * fraction).toNumber();
                if (topY < 0) { topY = 0; }
                if (topY > baseY) { topY = baseY; }

                var actualWidth = stripWidth;
                if (sx + actualWidth > x2) {
                    actualWidth = x2 - sx;
                }
                if (sx + actualWidth > w) {
                    actualWidth = w - sx;
                }
                var fillHeight = baseY - topY;

                if (actualWidth > 0 && fillHeight > 0 && sx >= 0) {
                    dc.fillRectangle(sx, topY, actualWidth, fillHeight);
                }
            }
        }

        _terrainRenderStatus = "EDGE";
        dc.setPenWidth(2);
        dc.setColor(
            isDay ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY,
            Graphics.COLOR_TRANSPARENT
        );
        for (var n = 1; n < ridgeX.size(); n++) {
            dc.drawLine(
                ridgeX[n - 1], ridgeY[n - 1],
                ridgeX[n], ridgeY[n]
            );
        }
        return true;
    }

    private function _drawSeasonalDetails(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        isDay as Boolean,
        sleepMode as Boolean,
        shift as Number
    ) as Void {
        if (sleepMode || !_seasonalDetails()) { return; }

        var baseY = sleepMode
            ? (h * 0.84).toNumber()
            : (_showStatusLine() ? (h * 0.835).toNumber() : h - 1);

        // Seasonal life belongs to the green foreground/ground ridge, not the
        // lifted gray depth ridge used by the survey-grid top boundary.
        var groundTop = _frontTerrainTopMask(w, h, baseY, shift);
        if (groundTop.size() < w) { return; }

        var seasonInfo = _seasonInfo();
        var season = seasonInfo[0] as Number;
        var progress = seasonInfo[1] as Number;
        var count = 5 + (progress / 12).toNumber();
        if (season == 3) { count = 8 + (progress / 4).toNumber(); }
        else if (season == 0) { count = 6 + (progress / 8).toNumber(); }
        if (count < 5) { count = 5; }
        if (count > 32) { count = 32; }

        // Deterministic but organic-looking scatter. Use separate hashed seeds
        // for x placement, terrain depth and local jitter so the accents stay
        // stable throughout the season without falling into visible diagonal
        // lines or rows.
        for (var i = 0; i < count; i++) {
            var seed = (i + 1) * 131 + season * 67 + 19;
            var xSeed = ((seed * seed * 17) + (seed * 29) + 71) % 1009;
            var frac = 0.04 + (xSeed.toDouble() / 1008.0) * 0.92;
            var x = Math.round(frac * (w - 1).toDouble()).toNumber();

            var xJitterSeed = ((seed * 43) + (seed * seed * 5) + 13) % 9;
            x += xJitterSeed - 4;
            if (x < 3 || x >= w - 3) { continue; }

            var top = groundTop[x];
            var available = baseY - top - 5;
            if (available < 4) { continue; }

            var coverage = 0.45;
            if (season == 3) { coverage = 0.32 + 0.66 * progress.toDouble() / 100.0; }
            else if (season == 0) { coverage = 0.25 + 0.50 * progress.toDouble() / 100.0; }
            else if (season == 1) { coverage = 0.18 + 0.38 * progress.toDouble() / 100.0; }
            else { coverage = 0.24 + 0.42 * progress.toDouble() / 100.0; }

            var depthSeed = ((seed * seed * 11) + (seed * 7) + 31) % 997;
            var depthFrac = depthSeed.toDouble() / 996.0;
            var depth = 3 + Math.round(depthFrac * available.toDouble() * coverage).toNumber();
            var y = top + depth;

            var yJitterSeed = ((seed * 59) + (seed * seed * 3) + 17) % 7;
            y += yJitterSeed - 3;

            if (y >= baseY - 3) { y = baseY - 4; }
            if (y <= top + 1) { y = top + 2; }

            if (season == 0) {
                var snow = isDay
                    ? Graphics.createColor(255, 205, 214, 219)
                    : Graphics.createColor(255, 105, 112, 116);
                dc.setColor(snow, Graphics.COLOR_TRANSPARENT);
                var patch = 2 + ((i + progress / 25) % 4);
                dc.drawLine(x - patch, y, x + patch, y);
                if (progress >= 45 && (i % 2) == 0) {
                    dc.fillCircle(x + 2, y + 3, 1);
                }
            } else if (season == 1) {
                var springGreen = isDay
                    ? Graphics.createColor(255, 95, 139, 81)
                    : Graphics.createColor(255, 53, 78, 49);
                dc.setColor(springGreen, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(x, y + 3, x, y - 1);
                dc.fillCircle(x - 1, y - 2, 1);
                if (progress >= 55 && (i % 3) == 0) {
                    var blossom = isDay
                        ? Graphics.createColor(255, 185, 132, 145)
                        : Graphics.createColor(255, 92, 67, 74);
                    dc.setColor(blossom, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(x + 2, y - 1, 1);
                }
            } else if (season == 2) {
                var summerGreen = isDay
                    ? Graphics.createColor(255, 43, 92, 48)
                    : Graphics.createColor(255, 29, 55, 32);
                dc.setColor(summerGreen, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(x, y + 4, x, y);
                dc.fillCircle(x - 1, y - 1, 2);
                if (progress >= 60 && (i % 2) == 0) {
                    dc.fillCircle(x + 3, y + 1, 1);
                }
            } else {
                var fallLeaf = isDay
                    ? Graphics.createColor(255, 156, 95, 42)
                    : Graphics.createColor(255, 83, 54, 30);
                dc.setColor(fallLeaf, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, 1);
                dc.fillCircle(x + 2, y + 2, 1);
                if (progress >= 45 && (i % 2) == 0) {
                    dc.fillCircle(x - 2, y + 1, 1);
                }
                if (progress >= 75 && (i % 3) == 0) {
                    var lateLeaf = isDay
                        ? Graphics.createColor(255, 174, 128, 55)
                        : Graphics.createColor(255, 91, 69, 34);
                    dc.setColor(lateLeaf, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(x + 4, y - 1, 1);
                }
            }
        }
    }

    private function _seasonInfo() as Array {
        var info = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var month = info.month;
        var day = info.day;
        var season = 0;
        var index = 0;
        var total = 90;

        if (month == 12 || month == 1 || month == 2) {
            season = 0;
            total = 90;
            if (month == 12) { index = day - 1; }
            else if (month == 1) { index = 31 + day - 1; }
            else { index = 62 + day - 1; }
        } else if (month >= 3 && month <= 5) {
            season = 1;
            total = 92;
            if (month == 3) { index = day - 1; }
            else if (month == 4) { index = 31 + day - 1; }
            else { index = 61 + day - 1; }
        } else if (month >= 6 && month <= 8) {
            season = 2;
            total = 92;
            if (month == 6) { index = day - 1; }
            else if (month == 7) { index = 30 + day - 1; }
            else { index = 61 + day - 1; }
        } else {
            season = 3;
            total = 91;
            if (month == 9) { index = day - 1; }
            else if (month == 10) { index = 30 + day - 1; }
            else { index = 61 + day - 1; }
        }

        var progress = Math.round(index.toDouble() * 100.0 / (total - 1).toDouble()).toNumber();
        if (progress < 0) { progress = 0; }
        if (progress > 100) { progress = 100; }
        return [season, progress];
    }

    private function _drawWeatherAtmosphere(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        isDay as Boolean,
        condition
    ) as Void {
        if (!_weatherStyling() || condition == null || !(condition instanceof Number)) {
            return;
        }

        var c = condition as Number;
        var x = _lastSkyVisible ? _lastSkyX : (w * 0.82).toNumber();
        var y = _lastSkyVisible ? _lastSkyY : (h * 0.16).toNumber();
        var layered = _largeCelestial() && _lastSkyVisible;
        var cloudColor = isDay
            ? Graphics.createColor(255, 76, 82, 88)
            : Graphics.createColor(255, 35, 42, 55);
        var cloudSize = layered ? 18 : 15;

        // Weather now belongs to the celestial scene rather than occupying a
        // disconnected row above the clock. In large-body mode clouds overlap
        // the lower/right part of the Sun/Moon and precipitation falls below.
        var cloudX = x + (layered ? 6 : 16);
        var cloudY = y + (layered ? 4 : 2);
        if (!layered) {
            // Keep normal-size weather toward the outside edge of the body,
            // away from the central time block.
            if (x > w / 2) { cloudX = x - 18; }
            else { cloudX = x + 18; }
        }

        switch (c) {
            case Weather.CONDITION_PARTLY_CLOUDY:
                _drawCloud(dc, cloudX, cloudY, cloudSize, cloudColor);
                break;
            case Weather.CONDITION_MOSTLY_CLOUDY:
                _drawCloud(dc, cloudX - 8, cloudY + 2, cloudSize, cloudColor);
                _drawCloud(dc, cloudX + 7, cloudY - 2, cloudSize + 2, cloudColor);
                break;
            case Weather.CONDITION_RAIN:
            case Weather.CONDITION_SCATTERED_SHOWERS:
            case Weather.CONDITION_UNKNOWN_PRECIPITATION:
                _drawCloud(dc, cloudX, cloudY, cloudSize + 2, cloudColor);
                _drawRain(dc, cloudX, cloudY + 12, 18, Graphics.COLOR_BLUE);
                break;
            case Weather.CONDITION_THUNDERSTORMS:
            case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
                _drawCloud(dc, cloudX, cloudY, cloudSize + 2, cloudColor);
                _drawRain(dc, cloudX - 5, cloudY + 12, 14, Graphics.COLOR_BLUE);
                dc.setPenWidth(2);
                dc.setColor(Graphics.COLOR_PURPLE, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(cloudX + 5, cloudY + 10, cloudX - 1, cloudY + 20);
                dc.drawLine(cloudX - 1, cloudY + 20, cloudX + 4, cloudY + 19);
                dc.drawLine(cloudX + 4, cloudY + 19, cloudX - 3, cloudY + 30);
                break;
            case Weather.CONDITION_SNOW:
            case Weather.CONDITION_WINTRY_MIX:
            case Weather.CONDITION_HAIL:
                _drawCloud(dc, cloudX, cloudY, cloudSize + 2, cloudColor);
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                for (var i = 0; i < 4; i++) {
                    dc.fillCircle(cloudX - 12 + i * 8,
                        cloudY + 15 + (i % 2) * 5, 1);
                }
                break;
            case Weather.CONDITION_WINDY:
                dc.setPenWidth(1);
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(cloudX - 22, cloudY - 5, cloudX + 12, cloudY - 5);
                dc.drawLine(cloudX - 14, cloudY + 4, cloudX + 18, cloudY + 4);
                dc.drawLine(cloudX - 5, cloudY + 13, cloudX + 24, cloudY + 13);
                break;
            case Weather.CONDITION_FOG:
            case Weather.CONDITION_HAZY:
                dc.setPenWidth(1);
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(cloudX - 22, cloudY - 5, cloudX + 22, cloudY - 5);
                dc.drawLine(cloudX - 16, cloudY + 4, cloudX + 18, cloudY + 4);
                dc.drawLine(cloudX - 10, cloudY + 13, cloudX + 24, cloudY + 13);
                break;
        }
    }

    private function _drawCloud(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        size as Number,
        color as Graphics.ColorType
    ) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - size / 3, y, size / 4);
        dc.fillCircle(x, y - size / 6, size / 3);
        dc.fillCircle(x + size / 3, y, size / 4);
        dc.fillRectangle(x - size / 2, y, size, size / 4);
    }

    private function _drawRain(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        width as Number,
        color as Graphics.ColorType
    ) as Void {
        dc.setPenWidth(2);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i = -1; i <= 1; i++) {
            var rx = x + i * (width / 3);
            dc.drawLine(rx, y, rx - 4, y + 11);
        }
    }

    private function _terrainColor(
        isDay as Boolean,
        condition
    ) as Graphics.ColorType {
        // Night is dark graphite/forest-rock rather than saturated blue,
        // which made the mountains read like an ocean.
        if (!isDay) {
            return Graphics.createColor(255, 42, 48, 43);
        }
        if (!_weatherStyling() || condition == null ||
            !(condition instanceof Number)) {
            return Graphics.createColor(255, 42, 83, 52);
        }
        var c = condition as Number;
        if (
            c == Weather.CONDITION_RAIN ||
            c == Weather.CONDITION_SCATTERED_SHOWERS ||
            c == Weather.CONDITION_THUNDERSTORMS ||
            c == Weather.CONDITION_SCATTERED_THUNDERSTORMS ||
            c == Weather.CONDITION_UNKNOWN_PRECIPITATION
        ) {
            return Graphics.createColor(255, 43, 61, 58);
        }
        if (
            c == Weather.CONDITION_SNOW ||
            c == Weather.CONDITION_WINTRY_MIX ||
            c == Weather.CONDITION_HAIL ||
            c == Weather.CONDITION_FOG ||
            c == Weather.CONDITION_HAZY
        ) {
            return Graphics.createColor(255, 65, 71, 68);
        }
        return Graphics.createColor(255, 42, 83, 52);
    }

    // 0 = original DEM-following low path; 1 = upper rim; 2 = hidden.
    // These are scenic tracks, not astronomical azimuth/elevation displays.
    private function _celestialPath() as Number {
        try {
            var value = Application.Properties.getValue(
                FaceKeys.CELESTIAL_PATH
            );
            if (value instanceof Number) {
                var mode = value as Number;
                if (mode >= 0 && mode <= 2) { return mode; }
            }
        } catch (e) {}
        return 1;
    }

    private function _horizonGlow() as Boolean {
        try {
            var setting = Application.Properties.getValue(
                FaceKeys.HORIZON_GLOW
            );
            if (setting instanceof Boolean) {
                return setting as Boolean;
            }
        } catch (e) {}
        return true;
    }

    private function _seasonalDetails() as Boolean {
        try {
            var value = Application.Properties.getValue(FaceKeys.SEASONAL_DETAILS);
            if (value instanceof Boolean) {
                return value as Boolean;
            }
        } catch (e) {}
        return true;
    }

    // 0=black, 1=day+twilight, 2=full cycle, 3=black day + colored night.
    private function _skyBackgroundMode() as Number {
        try {
            var value = Application.Properties.getValue(FaceKeys.SKY_BACKGROUND);
            if (value instanceof Number) {
                var mode = value as Number;
                if (mode >= 0 && mode <= 3) { return mode; }
            }
        } catch (e) {}
        return 0;
    }

    private function _skyBrightness() as Number {
        try {
            var value = Application.Properties.getValue(FaceKeys.SKY_BRIGHTNESS);
            if (value instanceof Number) {
                var mode = value as Number;
                if (mode >= 0 && mode <= 2) { return mode; }
            }
        } catch (e) {}
        return 1;
    }

    private function _skyDitherMode() as Number {
        try {
            var value = Application.Properties.getValue(FaceKeys.SKY_DITHER);
            if (value instanceof Number) {
                var mode = value as Number;
                if (mode >= 0 && mode <= 7) { return mode; }
            }
        } catch (e) {}
        return 0;
    }

    private function _skyDimGrid() as Boolean {
        try {
            var value = Application.Properties.getValue(FaceKeys.SKY_DIM_GRID);
            if (value instanceof Boolean) { return value as Boolean; }
        } catch (e) {}
        return false;
    }

    private function _largeCelestial() as Boolean {
        try {
            var value = Application.Properties.getValue(FaceKeys.LARGE_CELESTIAL);
            if (value instanceof Boolean) { return value as Boolean; }
        } catch (e) {}
        return false;
    }

    private function _weatherStyling() as Boolean {
        try {
            var value = Application.Properties.getValue(FaceKeys.WEATHER_STYLING);
            if (value instanceof Boolean) {
                return value as Boolean;
            }
        } catch (e) {}
        return true;
    }

    private function _demTerrainEnabled() as Boolean {
        if (!FaceConfig.DEM_APPROX_ENABLED) {
            return false;
        }
        try {
            var value = Application.Properties.getValue(FaceKeys.DEM_TERRAIN);
            if (value instanceof Boolean) {
                return value as Boolean;
            }
        } catch (e) {}
        return true;
    }

    private function _refreshWeatherLazy() as Void {
        _weatherProbeDone = true;
        if (!_weatherStyling()) {
            return;
        }

        var now = Time.now().value();
        var last = Application.Storage.getValue(FaceKeys.WEATHER_TIME);
        if (
            last != null && (last instanceof Number || last instanceof Long) &&
            now - last.toNumber() >= 0 &&
            now - last.toNumber() < FaceConfig.WEATHER_REFRESH_SECONDS
        ) {
            return;
        }

        try {
            var current = Weather.getCurrentConditions();
            if (current != null && current.condition != null) {
                Application.Storage.setValue(
                    FaceKeys.WEATHER_CONDITION,
                    current.condition
                );
                Application.Storage.setValue(FaceKeys.WEATHER_TIME, now);
                WatchUi.requestUpdate();
            }
        } catch (e) {}
    }

    private function _weatherCondition() {
        if (!_weatherStyling()) {
            return null;
        }
        return Application.Storage.getValue(FaceKeys.WEATHER_CONDITION);
    }

    private function _demTerrainAvailable() as Boolean {
        if (!_demTerrainEnabled()) {
            return false;
        }

        var raw = Application.Storage.getValue(FaceKeys.DEM_PROFILE_RAW);
        var profileLat = Application.Storage.getValue(FaceKeys.DEM_PROFILE_LAT);
        var profileLon = Application.Storage.getValue(FaceKeys.DEM_PROFILE_LON);
        var stamp = Application.Storage.getValue(FaceKeys.DEM_PROFILE_TIME);
        var lat = Application.Storage.getValue(FaceKeys.LAT);
        var lon = Application.Storage.getValue(FaceKeys.LON);

        if (
            raw == null || !(raw instanceof String) ||
            profileLat == null || profileLon == null || stamp == null ||
            lat == null || lon == null ||
            !(stamp instanceof Number || stamp instanceof Long)
        ) {
            return false;
        }

        var age = Time.now().value() - stamp.toNumber();
        if (age < 0 || age > FaceConfig.DEM_MAX_AGE_SECONDS) {
            return false;
        }

        try {
            return DemTerrain.distanceKm(
                profileLat as Double,
                profileLon as Double,
                lat as Double,
                lon as Double
            ) <= FaceConfig.DEM_REBUILD_DISTANCE_KM;
        } catch (e) {
            return false;
        }
    }

    private function _showYamakageLabel() as Boolean {
        try {
            var value = Application.Properties.getValue(FaceKeys.SHOW_YAMAKAGE_LABEL);
            if (value instanceof Boolean) {
                return value as Boolean;
            }
        } catch (e) {}
        return true;
    }

    private function _showTimeColon() as Boolean {
        try {
            var value = Application.Properties.getValue(FaceKeys.SHOW_TIME_COLON);
            if (value instanceof Boolean) {
                return value as Boolean;
            }
        } catch (e) {}
        return true;
    }

    private function _showSeconds() as Boolean {
        try {
            var value = Application.Properties.getValue(FaceKeys.SHOW_SECONDS);
            if (value instanceof Boolean) {
                return value as Boolean;
            }
        } catch (e) {}
        return true;
    }

    // Existing DimAod stays the master switch for backwards compatibility.
    // 0=normal, 1=dim, 2=very dim, 3=ultra dim.
    private function _aodDimLevel() as Number {
        if (!_dimAod()) { return 0; }
        try {
            var setting = Application.Properties.getValue(FaceKeys.AOD_DIM_LEVEL);
            if (setting instanceof Number) {
                var level = setting as Number;
                if (level < 0) { return 0; }
                if (level > 3) { return 3; }
                return level;
            }
        } catch (e) {}
        return 2;
    }

    // 0=disabled; 1=25%; 2=50%; 3=75%. Opaque black mask is
    // designed for the existing AMOLED AOD minute cadence, no timer.
    private function _aodDotMode() as Number {
        try {
            var value = Application.Properties.getValue(FaceKeys.AOD_DOT_MASK);
            if (value instanceof Number) {
                var setting = value as Number;
                if (setting >= 0 && setting <= 3) { return setting; }
            }
        } catch (e) {}
        return 3;
    }

    private function _ensureAodDotTiles() as Void {
        var mode = _aodDotMode();
        if (mode == _aodDotLoadedMode) { return; }

        // Never retain the old mask after a setting change; a failed resource
        // load merely disables the effect, not the watch face.
        _aodDotTiles = null;
        _aodDotLoadedMode = mode;
        if (mode == 0) { return; }
        try {
            if (mode == 1) {
                _aodDotTiles = [
                    WatchUi.loadResource(Rez.Drawables.AodDotsSparse0),
                    WatchUi.loadResource(Rez.Drawables.AodDotsSparse1),
                    WatchUi.loadResource(Rez.Drawables.AodDotsSparse2),
                    WatchUi.loadResource(Rez.Drawables.AodDotsSparse3)
                ];
            } else if (mode == 2) {
                _aodDotTiles = [
                    WatchUi.loadResource(Rez.Drawables.AodDotsBalanced0),
                    WatchUi.loadResource(Rez.Drawables.AodDotsBalanced1),
                    WatchUi.loadResource(Rez.Drawables.AodDotsBalanced2),
                    WatchUi.loadResource(Rez.Drawables.AodDotsBalanced3)
                ];
            } else {
                _aodDotTiles = [
                    WatchUi.loadResource(Rez.Drawables.AodDotsStrong0),
                    WatchUi.loadResource(Rez.Drawables.AodDotsStrong1),
                    WatchUi.loadResource(Rez.Drawables.AodDotsStrong2),
                    WatchUi.loadResource(Rez.Drawables.AodDotsStrong3)
                ];
            }
        } catch (e) {
            _aodDotTiles = null;
        }
    }

    private function _drawAodDotMask(
        dc as Graphics.Dc,
        w as Number,
        h as Number
    ) as Void {
        if (_aodDotMode() == 0) { return; }
        // Avoid work beyond the existing once-per-minute AOD frame.
        _ensureAodDotTiles();
        if (_aodDotTiles == null) { return; }

        try {
            var tiles = _aodDotTiles as Array;
            var nowInfo = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var phase = nowInfo.min % 4;
            var mask = tiles[phase];
            if (mask == null) { return; }
            // 60x60 pattern repeats with no seams, ~64 draws/frame instead
            // of thousands of tiny individual rectangle calls.
            var x = 0;
            while (x < w) {
                var y = 0;
                while (y < h) {
                    dc.drawBitmap(x, y, mask);
                    y += 60;
                }
                x += 60;
            }
        } catch (e) {
            // Mask must never compromise the working terrain/clock pipeline.
        }
    }

    private function _gridOverlay() as Boolean {
        try {
            var setting = Application.Properties.getValue(FaceKeys.GRID_OVERLAY);
            if (setting instanceof Boolean) { return setting as Boolean; }
        } catch (e) {}
        return true;
    }

    private function _gridInAod() as Boolean {
        try {
            var setting = Application.Properties.getValue(FaceKeys.GRID_IN_AOD);
            if (setting instanceof Boolean) { return setting as Boolean; }
        } catch (e) {}
        return false;
    }

    // Deliberately low-opacity grid. Garmin's setStroke accepts ARGB values
    // and blends them over the existing terrain/sky on supported AMOLED DCs.
    // Keep this last among primitives, so pen state cannot change ridge fills.
    private function _drawGridOverlay(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        sleepMode as Boolean,
        shift as Number
    ) as Void {
        try {
            var alpha = 42;
            if (sleepMode) {
                alpha = _aodDimLevel() >= 3 ? 8 : 14;
            }
            dc.setPenWidth(1);
            dc.setStroke(Graphics.createColor(alpha, 99, 125, 116));

            var baseY = sleepMode
                ? (h * 0.84).toNumber()
                : (_showStatusLine() ? (h * 0.835).toNumber() : h - 1);
            var topByX = _terrainTopMask(w, h, baseY, shift);
            if (topByX.size() < w) { return; }

            var x1 = w - 1;
            var bottom = h - 1;
            var gridStep = (w / 11.0).toNumber();
            if (gridStep < 12) { gridStep = 12; }

            // Full-width vertical survey lines, clipped at the actual top of
            // the terrain. Nothing is drawn into the sky.
            var gx = 0;
            while (gx <= x1) {
                var top = topByX[gx];
                if (top < bottom) {
                    dc.drawLine(gx, top, gx, bottom);
                }
                gx += gridStep;
            }

            // Horizontal lines are emitted only for contiguous x-runs where
            // that y-value is inside the terrain silhouette. This keeps the
            // surveying motif on the land while still reaching both edges.
            var minTop = bottom;
            for (var mi = 0; mi < w; mi++) {
                if (topByX[mi] < minTop) { minTop = topByX[mi]; }
            }
            var gy = minTop;
            while (gy <= bottom) {
                var runStart = -1;
                for (var px = 0; px < w; px++) {
                    if (gy >= topByX[px]) {
                        if (runStart < 0) { runStart = px; }
                    } else if (runStart >= 0) {
                        dc.drawLine(runStart, gy, px - 1, gy);
                        runStart = -1;
                    }
                }
                if (runStart >= 0) {
                    dc.drawLine(runStart, gy, x1, gy);
                }
                gy += gridStep;
            }
        } catch (e) {
            // Grid is decorative: never jeopardize the primary watch face.
        }
    }

    private function _frameMaskMatches(
        w as Number,
        h as Number,
        baseY as Number,
        shift as Number
    ) as Boolean {
        return _frameMaskW == w && _frameMaskH == h &&
            _frameMaskBaseY == baseY && _frameMaskShift == shift;
    }

    private function _cacheTerrainMasks(
        ridgeX as Array<Number>,
        ridgeY as Array<Number>,
        rearY as Array<Number>,
        w as Number,
        h as Number,
        baseY as Number,
        shift as Number
    ) as Void {
        var front = [] as Array<Number>;
        var rear = [] as Array<Number>;
        for (var i = 0; i < w; i++) {
            front.add(baseY);
            rear.add(baseY);
        }
        _applyTerrainMaskPolyline(front, ridgeX, ridgeY, w);
        _applyTerrainMaskPolyline(rear, ridgeX, rearY, w);
        _frameFrontMask = front;
        _frameRearMask = rear;
        _frameMaskW = w;
        _frameMaskH = h;
        _frameMaskBaseY = baseY;
        _frameMaskShift = shift;
    }

    private function _cacheFallbackTerrainMasks(
        rearPoly as Array,
        frontPoly as Array,
        w as Number,
        h as Number,
        baseY as Number,
        shift as Number
    ) as Void {
        var front = [] as Array<Number>;
        var rear = [] as Array<Number>;
        for (var i = 0; i < w; i++) {
            front.add(baseY);
            rear.add(baseY);
        }
        var rx = [] as Array<Number>;
        var ry = [] as Array<Number>;
        var fx = [] as Array<Number>;
        var fy = [] as Array<Number>;
        for (var r = 0; r < rearPoly.size() - 1; r++) {
            rx.add(rearPoly[r][0].toNumber());
            ry.add(rearPoly[r][1].toNumber());
        }
        for (var f = 0; f < frontPoly.size() - 1; f++) {
            fx.add(frontPoly[f][0].toNumber());
            fy.add(frontPoly[f][1].toNumber());
        }
        _applyTerrainMaskPolyline(rear, rx, ry, w);
        _applyTerrainMaskPolyline(front, fx, fy, w);
        _frameFrontMask = front;
        _frameRearMask = rear;
        _frameMaskW = w;
        _frameMaskH = h;
        _frameMaskBaseY = baseY;
        _frameMaskShift = shift;
    }

    private function _frontTerrainTopMask(
        w as Number,
        h as Number,
        baseY as Number,
        shift as Number
    ) as Array<Number> {
        if (_frameMaskMatches(w, h, baseY, shift) && _frameFrontMask != null) {
            return _frameFrontMask as Array<Number>;
        }
        var topByX = [] as Array<Number>;
        for (var i = 0; i < w; i++) { topByX.add(baseY); }

        try {
            var profile = _terrainProfile();
            if (profile != null && profile.size() >= 2) {
                    var step = profile[0] as Number;
                    var values = profile[1] as Array<Number>;
                    if (step > 0 && values.size() >= 3) {
                        var ridgeX = [] as Array<Number>;
                        var ridgeY = [] as Array<Number>;
                        var sampleCount = 13;
                        var horizonY = (h * 0.77).toNumber();
                        var verticalRange = h * 0.19 * _terrainVerticalScale();
                        var centerAz = _horizonCenterAz();
                        var sense = _horizonSense();
                        var azSpan = _terrainAzSpan();

                        for (var s = 0; s < sampleCount; s++) {
                            var frac = s.toDouble() /
                                (sampleCount - 1).toDouble();
                            var az = centerAz +
                                (frac - 0.5) * azSpan * sense;
                            while (az < 0.0) { az += 360.0; }
                            while (az >= 360.0) { az -= 360.0; }
                            var rounded = Math.round(az / step.toDouble());
                            var idx = rounded.toNumber() % values.size();
                            if (idx < 0) { idx += values.size(); }
                            var angle = values[idx].toDouble() / 10.0;
                            if (angle < -5.0) { angle = -5.0; }
                            if (angle > 45.0) { angle = 45.0; }
                            var sx = (frac * (w - 1)).toNumber() + shift;
                            if (sx < 0) { sx = 0; }
                            if (sx >= w) { sx = w - 1; }
                            var sy = (horizonY -
                                (angle / 45.0) * verticalRange).toNumber();
                            if (sy < 0) { sy = 0; }
                            if (sy > baseY) { sy = baseY; }
                            ridgeX.add(sx);
                            ridgeY.add(sy);
                        }

                        if (ridgeX.size() >= 2) {
                            _applyTerrainMaskPolyline(
                                topByX, ridgeX, ridgeY, w
                            );
                            return topByX;
                        }
                    }
                }
        } catch (e) {
            // Fall through to the foreground stock silhouette.
        }

        var fallbackX = [
            0,
            (w * 0.25).toNumber(),
            (w * 0.50).toNumber(),
            (w * 0.90).toNumber(),
            w - 1
        ] as Array<Number>;
        var fallbackY = [
            baseY,
            (h * 0.74).toNumber(),
            (h * 0.815).toNumber(),
            (h * 0.70).toNumber(),
            (h * 0.765).toNumber()
        ] as Array<Number>;
        _applyTerrainMaskPolyline(topByX, fallbackX, fallbackY, w);
        return topByX;
    }

    // Build a per-pixel top boundary for the terrain so the survey grid can
    // be clipped without relying on a graphics clip-path API. The boundary
    // follows the topmost (rear/gray) DEM ridge and falls back to the stock
    // silhouette if no terrain packet is available.
    private function _terrainTopMask(
        w as Number,
        h as Number,
        baseY as Number,
        shift as Number
    ) as Array<Number> {
        if (_frameMaskMatches(w, h, baseY, shift) && _frameRearMask != null) {
            return _frameRearMask as Array<Number>;
        }
        var topByX = [] as Array<Number>;
        for (var i = 0; i < w; i++) { topByX.add(baseY); }

        try {
            var profile = _terrainProfile();
            if (profile != null && profile.size() >= 2) {
                    var step = profile[0] as Number;
                    var values = profile[1] as Array<Number>;
                    if (step > 0 && values.size() >= 3) {
                        var ridgeX = [] as Array<Number>;
                        var ridgeY = [] as Array<Number>;
                        var rearY = [] as Array<Number>;
                        var sampleCount = 13;
                        var horizonY = (h * 0.77).toNumber();
                        var verticalRange = h * 0.19 * _terrainVerticalScale();
                        var centerAz = _horizonCenterAz();
                        var sense = _horizonSense();
                        var azSpan = _terrainAzSpan();

                        for (var s = 0; s < sampleCount; s++) {
                            var frac = s.toDouble() /
                                (sampleCount - 1).toDouble();
                            var az = centerAz +
                                (frac - 0.5) * azSpan * sense;
                            while (az < 0.0) { az += 360.0; }
                            while (az >= 360.0) { az -= 360.0; }

                            var rounded = Math.round(az / step.toDouble());
                            var idx = rounded.toNumber() % values.size();
                            if (idx < 0) { idx += values.size(); }
                            var angle = values[idx].toDouble() / 10.0;
                            if (angle < -5.0) { angle = -5.0; }
                            if (angle > 45.0) { angle = 45.0; }

                            var sx = (frac * (w - 1)).toNumber() + shift;
                            if (sx < 0) { sx = 0; }
                            if (sx >= w) { sx = w - 1; }
                            var sy = (horizonY -
                                (angle / 45.0) * verticalRange).toNumber();
                            if (sy < 0) { sy = 0; }
                            if (sy > baseY) { sy = baseY; }
                            ridgeX.add(sx);
                            ridgeY.add(sy);
                        }

                        if (ridgeX.size() >= 2) {
                            var rearLift = (h * (0.048 + 0.008 *
                                (_terrainVerticalScale() - 1.0))).toNumber();
                            for (var ri = 0; ri < ridgeY.size(); ri++) {
                                var before = ridgeY[ri == 0 ? 0 : ri - 1];
                                var after = ridgeY[ri + 1 < ridgeY.size()
                                    ? ri + 1 : ri];
                                var smoothed = ((before + 2 * ridgeY[ri] +
                                    after) / 4.0).toNumber();
                                var rearTop = smoothed - rearLift;
                                if (rearTop < 0) { rearTop = 0; }
                                if (rearTop > baseY) { rearTop = baseY; }
                                rearY.add(rearTop);
                            }
                            _applyTerrainMaskPolyline(
                                topByX, ridgeX, rearY, w
                            );
                            return topByX;
                        }
                    }
                }
        } catch (e) {
            // Fall through to the stock silhouette.
        }

        var fallbackX = [
            0,
            (w * 0.10).toNumber(),
            (w * 0.40).toNumber(),
            (w * 0.80).toNumber(),
            w - 1
        ] as Array<Number>;
        var fallbackY = [
            baseY,
            (h * 0.685).toNumber(),
            (h * 0.755).toNumber(),
            (h * 0.645).toNumber(),
            (h * 0.715).toNumber()
        ] as Array<Number>;
        _applyTerrainMaskPolyline(topByX, fallbackX, fallbackY, w);
        return topByX;
    }

    private function _applyTerrainMaskPolyline(
        topByX as Array<Number>,
        xs as Array<Number>,
        ys as Array<Number>,
        w as Number
    ) as Void {
        if (xs.size() < 2 || ys.size() < 2) { return; }
        for (var i = 1; i < xs.size(); i++) {
            var x0 = xs[i - 1];
            var x1 = xs[i];
            var y0 = ys[i - 1];
            var y1 = ys[i];
            var dx = x1 - x0;
            if (dx <= 0) { continue; }
            for (var x = x0; x <= x1; x++) {
                if (x < 0 || x >= w) { continue; }
                var f = (x - x0).toDouble() / dx.toDouble();
                var y = (y0.toDouble() +
                    (y1 - y0).toDouble() * f).toNumber();
                if (y < topByX[x]) { topByX[x] = y; }
            }
        }
    }

    private function _dimAod() as Boolean {
        try {
            var value = Application.Properties.getValue(FaceKeys.DIM_AOD);
            if (value instanceof Boolean) {
                return value as Boolean;
            }
        } catch (e) {}
        return true;
    }

    private function _showStatusLine() as Boolean {
        try {
            var value = Application.Properties.getValue(FaceKeys.SHOW_STATUS_LINE);
            if (value instanceof Boolean) {
                return value as Boolean;
            }
        } catch (e) {}
        return true;
    }

    private function _isYamakageAppInstalled() as Boolean {
        try {
            return System.isAppInstalled(FaceConfig.YAMAKAGE_APP_URI);
        } catch (e) {
            return false;
        }
    }

    private function _captureActivityLocation(force as Boolean) as Void {
        var now = Time.now().value();
        if (!force && now - _lastLocationProbe < 10) {
            return;
        }
        _lastLocationProbe = now;

        try {
            var info = Activity.getActivityInfo();
            if (info == null || info.currentLocation == null) {
                return;
            }

            var quality = info.currentLocationAccuracy;
            if (quality != null && quality < FaceConfig.MIN_LOCATION_QUALITY) {
                return;
            }

            var coords = info.currentLocation.toDegrees();
            if (coords == null || coords.size() < 2) {
                return;
            }

            Application.Storage.setValue(FaceKeys.LAT, coords[0]);
            Application.Storage.setValue(FaceKeys.LON, coords[1]);
            Application.Storage.setValue(FaceKeys.LOC_TIME, now);
            if (quality != null) {
                Application.Storage.setValue(FaceKeys.LOC_QUALITY, quality);
            }
        } catch (e) {
            // Continue using the last saved coordinate when Garmin no longer
            // exposes the activity fix.
        }
    }

    private function _refreshLocalSunData(force as Boolean) as Void {
        var lat = Application.Storage.getValue(FaceKeys.LAT);
        var lon = Application.Storage.getValue(FaceKeys.LON);
        if (lat == null || lon == null) {
            return;
        }

        var now = Time.now().value();
        var last = Application.Storage.getValue(FaceKeys.SUN_CALC_TIME);
        if (!force && last != null && (last instanceof Number || last instanceof Long)) {
            var age = now - last.toNumber();
            if (age >= 0 && age < FaceConfig.LOCAL_SUN_REFRESH_SECONDS) {
                return;
            }
        }

        try {
            var location = new Position.Location({
                :latitude => lat as Double,
                :longitude => lon as Double,
                :format => :degrees
            });

            var rise = Weather.getSunrise(location, Time.now());
            var set = Weather.getSunset(location, Time.now());
            if (rise != null && set != null) {
                Application.Storage.setValue(FaceKeys.STANDARD_SUNRISE, rise.value());
                Application.Storage.setValue(FaceKeys.STANDARD_SUNSET, set.value());
                Application.Storage.setValue(FaceKeys.SUN_CALC_TIME, now);
            }
        } catch (e) {
            // Keep the last valid sun data. This still leaves the face usable
            // if a firmware state temporarily cannot provide the calculation.
        }
    }

    private function _activeSunrise() {
        var terrain = Application.Storage.getValue(FaceKeys.SUNRISE);
        if (_enhancedDataFresh() && terrain != null &&
            (terrain instanceof Number || terrain instanceof Long) &&
            terrain.toNumber() > 0) {
            return terrain;
        }
        return Application.Storage.getValue(FaceKeys.STANDARD_SUNRISE);
    }

    private function _activeSunset() {
        var terrain = Application.Storage.getValue(FaceKeys.SUNSET);
        if (_enhancedDataFresh() && terrain != null &&
            (terrain instanceof Number || terrain instanceof Long) &&
            terrain.toNumber() > 0) {
            return terrain;
        }
        return Application.Storage.getValue(FaceKeys.STANDARD_SUNSET);
    }

    private function _enhancedDataFresh() as Boolean {
        var stamp = Application.Storage.getValue(FaceKeys.OFFICIAL_YK_TIME);
        if (stamp == null) {
            stamp = Application.Storage.getValue(FaceKeys.SUMMARY_TIME);
        }
        if (stamp == null) {
            // Legacy compatibility with pre-official companion event builds.
            stamp = Application.Storage.getValue(FaceKeys.COMPANION_TIME);
        }
        if (stamp == null || !(stamp instanceof Number || stamp instanceof Long)) {
            return false;
        }
        var age = Time.now().value() - stamp.toNumber();
        return age >= 0 && age <= FaceConfig.ENHANCED_MAX_AGE_SECONDS;
    }

    private function _isDaytime(now as Number, sunrise, sunset) as Boolean {
        if (
            sunrise != null && sunset != null &&
            (sunrise instanceof Number || sunrise instanceof Long) &&
            (sunset instanceof Number || sunset instanceof Long) &&
            sunrise.toNumber() > 0 && sunset.toNumber() > 0
        ) {
            return now >= sunrise.toNumber() && now < sunset.toNumber();
        }

        var info = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return info.hour >= 6 && info.hour < 18;
    }
}
