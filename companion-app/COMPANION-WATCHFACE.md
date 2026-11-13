# YAMAKAGE Watch App companion bridge

This build adds an **optional** Garmin Complications publisher to the existing
YAMAKAGE Device App. The original calculation, Panorama, SkyPlot, Radar,
Details, and Settings behavior is unchanged.

## Published channels

The app publishes two private custom complications when the device supports
`Toybox.Complications`:

- `YAMAKAGE Events` (`id=0`)
  - `E2|sunrise|sunset|sunUpdated|moonrise|moonset|moonUpdated`
  - values/timestamps are Unix seconds; `-1` means that domain has not yet
    produced a valid event.
- `YAMAKAGE Terrain` (`id=1`)
  - `T2|15|terrainUpdated|v0,v15,...,v345`
  - 24 terrain obstacle-angle samples at 15-degree azimuth spacing.
  - each value is degrees × 10 (signed integer).

Sun mode updates terrain sunrise/sunset and the horizon after its normal API
request. Moon mode updates terrain moonrise/moonset and the horizon. The last
good values are retained in app storage and republished on later launches.

## Compatibility

Custom complication publishing requires Connect IQ API 4.2+. The publisher is
runtime-guarded and does nothing when the module is unavailable. This alpha has
been prepared for the fēnix 8 Pro test target first; do a full legacy-product
export before replacing the broad upstream release.

The complications are marked `private`, so the Watch App and Watch Face must be
signed with the same developer key. This is ideal for current testing and keeps
the compact wire-format values out of Face It. For a future cross-publisher
release, change the access strategy deliberately rather than exposing the
technical payload by accident.

## API configuration

The supplied source archive still contains the sanitized placeholder
`https://example.invalid` / `development-placeholder` configuration. Restore
the normal production/local YAMAKAGE API config before testing live terrain
calculations.
