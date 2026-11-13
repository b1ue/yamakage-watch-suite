import Toybox.Lang;
module FaceConfig {
    // Keep disabled for the first compile/device pass. Enable only after the
    // compact watch-face endpoint and production credentials are configured.
    const API_ENABLED = false;

    const API_BASE_URL = "https://example.invalid";
    const SUMMARY_ENDPOINT = "/api/v1/watchface/summary";
    const API_KEY = "development-placeholder";

    // Original YAMAKAGE device-app manifest ID. The watch face can detect and
    // launch it without requiring any shared storage or server credentials.
    const YAMAKAGE_APP_URI = "manifest-id://871f6463-134b-4645-acea-86ef8773457e";

    // Official YAMAKAGE V1 public complication (Tomoo, app v2.3.4+).
    // The November 3 background-update fix standardizes the developer CSV
    // lookup key as "YK CSV". Keep the earlier documented label as a legacy
    // fallback so the face can bridge installations during rollout.
    const OFFICIAL_YK_CSV_LABEL = "YK CSV";
    const OFFICIAL_YK_CSV_LEGACY_LABEL = "YK Dev CSV";

    // Experimental/additive terrain complication from our companion build.
    // Official YAMAKAGE currently publishes terrain-aware event times but not
    // the horizon profile itself, so this remains the visual terrain source.
    const COMPANION_TERRAIN_LABEL = "YAMAKAGE Terrain";
    const ENHANCED_MAX_AGE_SECONDS = 36 * 60 * 60;

    // The background service wakes hourly. It can choose not to make a request
    // when the cached summary is still fresh.
    const BACKGROUND_INTERVAL_SECONDS = 60 * 60;
    const SUMMARY_MAX_AGE_SECONDS = 6 * 60 * 60;

    // Activity.Info.currentLocation is cached only when the reported Garmin
    // quality is at least this value. Garmin: 2=poor, 3=usable, 4=good.
    // Keep 2 here because the proven alpha-4 capture path accepted it; a better
    // fix received later will simply replace the cached coordinate.
    const MIN_LOCATION_QUALITY = 2;

    // Standard sunrise/sunset is recalculated locally at most this often.
    const LOCAL_SUN_REFRESH_SECONDS = 10 * 60;

    // Experimental safe-path features. These never run during initial view
    // creation; the face renders first and probes them lazily afterward.
    const WEATHER_REFRESH_SECONDS = 10 * 60;
    const DEM_APPROX_ENABLED = false;
    const DEM_ELEVATION_URL = "https://api.open-meteo.com/v1/elevation";
    const DEM_REBUILD_DISTANCE_KM = 5.0;
    const DEM_MAX_AGE_SECONDS = 365 * 24 * 60 * 60;
}
