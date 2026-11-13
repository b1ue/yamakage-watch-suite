# YAMAKAGE Watch Suite

Garmin Connect IQ source for the YAMAKAGE watch face and its companion watch app.

This repository keeps the two installable projects together because they share a custom Garmin Complications bridge:

- [`watch-face/`](watch-face/) — the glanceable watch face, currently `v0.1.0-alpha7.6.11.6.9`.
- [`companion-app/`](companion-app/) — the full YAMAKAGE watch app and terrain publisher, currently `v2.3.2`.

The watch face works on its own with Garmin-provided location and weather data. When the companion app publishes a `YAMAKAGE Terrain` complication, the face can render the received terrain profile. See [`watch-face/COMPANION-INTEGRATION.md`](watch-face/COMPANION-INTEGRATION.md) and [`companion-app/COMPANION-WATCHFACE.md`](companion-app/COMPANION-WATCHFACE.md) for protocol details and current limitations.

## Repository layout

```text
.
|-- watch-face/       # Watch-face Monkey C source and resources
|-- companion-app/    # Full watch app, publisher, tests, and assets
|-- LICENSE
`-- README.md
```

## Development setup

Install the [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/overview/) and create a local developer key. Private keys, local environment files, generated binaries, and companion API configuration are intentionally excluded from Git.

For the companion app:

1. Copy `companion-app/.env.example` to `companion-app/.env` and fill in local SDK paths.
2. Copy `companion-app/source/core/Config.example.mc` to `companion-app/source/core/Config.mc` and add the required local API configuration.
3. In `companion-app/`, install the development dependencies with `pnpm install`.
4. Use the scripts in `companion-app/package.json` to build, run, test, or export the app.

The watch face is a standard Connect IQ project rooted at `watch-face/`, with `manifest.xml`, `monkey.jungle`, `source/`, and `resources/` ready to open in the Garmin tooling.

## Status

Both projects are experimental alpha software. The watch-face archive was structurally checked but was not SDK-compiled as part of this repository import. Always-on display behavior and the moving black-dot mask are experimental and do not guarantee burn-in prevention.

## Credits and license

YAMAKAGE was created by **Ichimura Tomoo**. This adaptation preserves the original attribution, project history, icon resources, and MIT license. See [`watch-face/ORIGINAL_PROJECT.md`](watch-face/ORIGINAL_PROJECT.md) for additional attribution details.

Licensed under the [MIT License](LICENSE).
