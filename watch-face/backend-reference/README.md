# Compact watch-face API recommendation

The current upstream Watch App route intentionally returns terrain profile and path arrays for Panorama/SkyPlot/Radar. A Connect IQ background service has a much smaller heap, so a watch-face-specific summary route is safer.

Recommended new route:

`POST /api/v1/watchface/summary`

Return only the eight numeric values documented in the root README.

The watch face already targets this route when `FaceConfig.API_ENABLED = true`.

A backend implementation should reuse the same auth middleware, elevation repository, and `calculateShadow` / `calculateMoonShadow` use cases used by the existing Watch App endpoints. It should avoid returning `azimuthProfiles` and full path arrays.

This folder is a design handoff rather than a modification to Tomoo's upstream backend; it keeps the alpha watch-face project self-contained until the backend owner decides how they want to expose the summary API.
