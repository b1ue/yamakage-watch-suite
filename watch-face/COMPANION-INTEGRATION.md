# YAMAKAGE Device App → Watch Face bridge

Alpha 7 contains the **subscriber** side of an optional Garmin Complications bridge.

The currently reviewed/original YAMAKAGE Device App does not publish these complications yet, so alpha 7.1 continues to use Garmin's local sunrise/sunset unless a compatible publisher is present.

## Reserved custom complications

A future additive Device App update can publish:

1. **YAMAKAGE Sunrise** — numeric Unix timestamp (terrain-adjusted sunrise)
2. **YAMAKAGE Sunset** — numeric Unix timestamp (terrain-adjusted sunset/shadow time)
3. **YAMAKAGE Terrain** — optional compact String representation of the azimuth terrain profile

The face scans available complications by `longLabel`, subscribes to these names when found, and caches updates. Enhanced values expire after 36 hours and fall back to Garmin horizon calculations.

## Why Complications

Connect IQ application storage is app-local; a watch face cannot directly read the Device App's storage. Garmin's custom Complications framework is the supported publish/subscribe channel from Device Apps to Watch Faces.

## Terrain proposal

The original Watch App receives a 360° azimuth profile with an elevation/obstacle angle for each sample. For the face, the publisher should downsample that to a compact set (for example 24 values at 15° spacing), encode it as a short ASCII string, and publish it as `YAMAKAGE Terrain`.

The watch face can then render the horizon centered around the current solar azimuth. Until that bridge is implemented, the alpha 7.1 mountain artwork remains deliberately stylized and is **not** represented as local terrain.

## Current direct integration

Even without a publisher update, alpha 7.1 can:

- detect the original YAMAKAGE app by manifest ID;
- show `APP` in the status line when installed;
- launch the full Device App by pressing the lower terrain/status area.
