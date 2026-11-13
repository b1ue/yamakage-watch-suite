module FaceKeys {
    const SHOW_YAMAKAGE_LABEL = "ShowYamakageLabel";
    const SHOW_TIME_COLON = "ShowTimeColon";
    const SHOW_SECONDS = "ShowSeconds";
    const DIM_AOD = "DimAod";
    const AOD_DIM_LEVEL = "AodDimLevel";
    const GRID_OVERLAY = "GridOverlay";
    const GRID_IN_AOD = "GridInAod";
    const AOD_DOT_MASK = "AodDotMask";
    const SHOW_STATUS_LINE = "ShowStatusLine";
    const WEATHER_STYLING = "WeatherStyling";
    const HORIZON_GLOW = "HorizonGlow";
    const CELESTIAL_PATH = "CelestialPath";
    const TERRAIN_DETAIL = "TerrainDetail";
    const SEASONAL_DETAILS = "SeasonalDetails";
    const SKY_BACKGROUND = "SkyBackground";
    const SKY_DIM_GRID = "SkyDimGrid"; // legacy boolean, retained for upgrade compatibility
    const SKY_DITHER = "SkyDither";
    const SKY_BRIGHTNESS = "SkyBrightness";
    const LARGE_CELESTIAL = "LargeCelestial";
    const DEM_TERRAIN = "DemTerrain";
    const LAT = "loc_lat";
    const LON = "loc_lon";
    const LOC_TIME = "loc_time";
    const LOC_QUALITY = "loc_quality";
    const WEATHER_CONDITION = "weather_condition";
    const WEATHER_TIME = "weather_time";
    const DEM_PROFILE_RAW = "dem_profile_raw";
    const DEM_PROFILE_LAT = "dem_profile_lat";
    const DEM_PROFILE_LON = "dem_profile_lon";
    const DEM_PROFILE_TIME = "dem_profile_time";
    const DEM_STATUS = "dem_status";
    const DEM_ATTEMPT_TIME = "dem_attempt_time";
    const DEM_SCHEDULE_TIME = "dem_schedule_time";

    // Standard geometric horizon times calculated locally with Garmin Weather.
    const STANDARD_SUNSET = "standard_sunset";
    const STANDARD_SUNRISE = "standard_sunrise";
    const SUN_CALC_TIME = "sun_calc_time";

    // Terrain-aware YAMAKAGE times. These remain separate so a future backend
    // response can override/compare against Garmin horizon times cleanly.
    const SUNSET = "sunset";
    const SUNRISE = "sunrise";
    const SUN_ALTITUDE = "sun_altitude";
    const MOONSET = "moonset";
    const MOONRISE = "moonrise";
    const MOON_FRACTION = "moon_fraction";
    const MOON_PHASE = "moon_phase";
    const MOON_ALTITUDE = "moon_altitude";
    const SUMMARY_TIME = "summary_time";
    const OFFICIAL_YK_TIME = "official_yk_time";
    const OFFICIAL_YK_ALTITUDE = "official_yk_altitude";
    const TERRAIN_RX_TIME = "terrain_rx_time";
    const COMPANION_TIME = "companion_time";
    const TERRAIN_PROFILE_RAW = "terrain_profile_raw";
    const API_STATUS = "api_status";
    const COMPANION_PROBE_STATUS = "companion_probe_status";
}
