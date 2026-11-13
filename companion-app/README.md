## v2.3.2 publication diagnostic

After a successful DEM fetch, the app remains on the status page and shows:
- `TERRAIN SENT` only when `Complications.updateComplication()` returned without exception.
- `PUBLISH FAILED` if Garmin rejected the complication update.

## v2.3.1 terrain-sync diagnostic build

This build is intentionally named **YAMAKAGE Companion** and cannot call the
private/unconfigured YAMAKAGE backend.

START performs only:

GPS -> Open-Meteo DEM -> coarse terrain horizon -> private `YAMAKAGE Terrain`
complication -> return to Main.

Therefore:
- `API Error` cannot originate from this build's START path.
- Any error shown after START should say `Terrain Sync Error: <code>` or
  `Terrain Data Error`.
- This makes it easy to distinguish this development app from Tomoo's original
  YAMAKAGE installation.

## Companion alpha 2.5.1 manifest hotfix

- Restored the XML declaration to `<?xml version="1.0"?>`.
- Restored the Connect IQ manifest schema version to `3`.
- Set only the `<iq:application>` version to `2.3.0`.
- No runtime logic changed from alpha 2.5.

## Companion alpha 2.5 — terrain-sync mode when backend is unconfigured

The public development source intentionally ships with:

- `API_BASE_URL = "https://example.invalid"`
- `API_KEY = "development-placeholder"`

In this build, START detects that state and no longer sends a doomed YAMAKAGE
shadow request. Instead it performs a companion-only terrain sync:

GPS -> Open-Meteo elevation samples -> coarse horizon -> `YAMAKAGE Terrain`
complication -> return to Main.

If a real YAMAKAGE backend URL/key is configured later, START automatically
returns to the original YAMAKAGE calculation behavior while still refreshing
the companion terrain horizon in parallel.

Mapbox is not required for this interim path.

## Companion alpha 2.4 — dedicated development manifest ID

This companion-enabled development build now uses its own Connect IQ application ID:

`a09b6c7f-4898-4eb6-8f48-cf4cb0e1761b`

The prior build reused the fork/original app ID (`8e5a8671-27bf-45b2-9479-8675026ec1b7`), which can cause install/signature/version conflicts and prevents clean side-by-side testing with Tomoo's original YAMAKAGE app.

The complication channels remain private and are still intended to be consumed by a watch face built with the same Garmin developer key.

## Companion alpha 2.3 — fēnix 8 Pro validation target

- This development/export build is intentionally scoped to `fenix8pro47mm`, which is Garmin's Connect IQ target for the fēnix 8 Pro 47/51 mm AMOLED family.
- The prior 197-device export failed when it reached devices such as `gpsmaph1` that do not support custom complications. That was a support-matrix/resource issue, not a Monkey C application failure.
- Production test/benchmark source folders are omitted from this alpha bundle, removing irrelevant `TestFixture` warnings during normal builds.
- The broad upstream product list should be restored later with device-qualified complication resources once the companion protocol is proven on hardware.

## Companion alpha 2.2 compile hotfix

- Removed `private` from module-level helper functions in `CompanionPublisher.mc` and `DemTerrainFallback.mc`.
- Monkey C permits `private function` inside classes, but not at module scope.
- No runtime behavior changed from companion alpha 2.1.

## Companion alpha 2.1 resource hotfix

- Private complications no longer include `<faceIt>` metadata, which Garmin only permits for public/protected complications.
- `YAMAKAGE Events` and `YAMAKAGE Terrain` now use a dedicated `ComplicationIcon` resource instead of reusing the launcher icon ID.
- English (`eng`) was added to the manifest language list.
- The launcher resource is converted to a native 65x65 PNG when available to avoid target-size scaling warnings.
- Companion data remains private for same-developer-key local testing.

## Companion alpha 2: local DEM terrain bridge

This build keeps the original YAMAKAGE calculation flow intact and adds an
independent foreground terrain fallback for the sibling watch face.

Whenever a normal calculation is started and a location is available, the app
also samples the public Open-Meteo Copernicus GLO-90 elevation endpoint using
18 bearings x 3 distances (55 coordinates including the observer point). The
resulting coarse 20-degree horizon is published through the existing private
`YAMAKAGE Terrain` complication.

The DEM request does not replace Tomoo's backend. If the normal YAMAKAGE API
succeeds, its denser terrain profile is published afterward and naturally
supersedes the approximate fallback.


> Companion alpha note: this working copy adds an optional Device App → Watch Face bridge. See `COMPANION-WATCHFACE.md`. The core YAMAKAGE UI and calculation flow remain unchanged.

# YAMAKAGE (Garmin Connect IQ App)

## Overview

A Watch App(Device App) for Garmin devices (Edge, Fenix, Forerunner, etc.) that displays the "true sunrise and sunset times" by taking the surrounding terrain (elevation) into account.

It communicates with a dedicated backend server (YAMAKAGE API) to calculate the height of surrounding mountains and obstacles from your current location, predicting accurate daylight hours.

---

## Preparation (Garmin SDK Setup)

Before starting development, you need to prepare the official Garmin Connect IQ development environment.

### 1. Installing Connect IQ SDK Manager

Download and install the "Connect IQ SDK Manager" from the Garmin [developer site](https://developer.garmin.com/connect-iq/overview/), and download the latest SDK.

### 2. Creating a Developer Key

Create a private key (`.der` file) to build and sign the app.
Open a terminal and use the `monkeyc` command located in the SDK's `bin` directory to generate the key.

```sh
# Example key generation command (replace the path with your environment's bin path)
/path/to/connectiq-sdk/bin/monkeyc -a developer_key.der

```

Place the generated `developer_key.der` in the project's root directory (Note: It will not be committed to Git as it is excluded via `.gitignore`).

---

## Environment Setup

### 1. Installing `pnpm`

We use `pnpm` as the package manager and script runner.

```sh
npm install -g pnpm

```

### 2. Installing Dependencies

Run the following command in the directory containing `package.json` to install development tools such as the code formatter (Prettier).

```sh
pnpm install

```

### 3. Setting Up Environment Variables

Copy `.env.example` in the project root to create `.env`, and configure the necessary environment variables for your setup.

```sh
cp .env.example .env

```

Please enter the following variables in the `.env` file according to your environment.

| Variable Name | Description | Example (Windows) | Example (Mac) |
| --- | --- | --- | --- |
| `GARMIN_DEVICE` | The target device ID to launch and test in the simulator. | `edge1040` | `edge1040` |
| `GARMIN_KEY_PATH` | Absolute (or relative) path to the created developer key. | `C:\keys\developer_key.der` | `/Users/name/keys/developer_key.der` |
| `GARMIN_SDK_BIN` | Absolute path to the `bin` folder of the downloaded Garmin SDK. | `C:\Users\name\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-X.Y.Z\bin` | `/Users/name/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-X.Y.Z/bin` |

---

## Local Execution & Development

### 1. Launching the Simulator

Running the following command will automatically build the code and launch the simulator for the configured `GARMIN_DEVICE`.

```sh
pnpm run dev

```

---

## Commands

| Command | Description |
| --- | --- |
| `pnpm run dev` | Executes a debug build and launches the simulator. |
| `pnpm run dev:release` | Launches the simulator with a release build (optimized). |
| `pnpm run test` | Builds unit tests and executes them on the simulator. |
| `pnpm run fmt` | Formats the code using Prettier (monkeyc plugin). |
| `pnpm run export` | Exports the `.iq` file for submission to the Connect IQ Store. |

---

## Creating the Store Release File

Follow these steps to generate the `.iq` file required for submitting the app to the Connect IQ Store.
Run the following command:

```sh
pnpm run export

```

Once the process is complete, a file named `yamakage-watch-app.iq` will be generated inside the project's `bin` directory.

Uploading this file via the [Garmin Developer Dashboard](https://www.google.com/search?q=https://developer.garmin.com/connect-iq/overview/) will complete your application for store release.

---

## License

This project is licensed under the [MIT License](https://www.google.com/search?q=./LICENSE).