# Trading Tracker

Offline trading portfolio tracker — Dashboard, Open Positions, Position Detail,
Edit Lot, Square Off, Closed Trades, XIRR, Backup & Restore.

- **All data stays on your phone.** It's stored in a local SQLite database
  inside the app's private storage. Nothing is ever sent over the network.
- **Backup / Restore** lets you export the database file anywhere (Google
  Drive, email, another folder) and restore from it later, including on a
  different device.

## Project layout

```
lib/
  main.dart                 # app entry + bottom nav shell
  theme.dart                 # colors, card style
  models.dart                 # Position, Lot
  db_helper.dart              # SQLite (sqflite) access layer
  xirr.dart                   # XIRR (Newton-Raphson) calculator
  backup_service.dart         # export/import the .db file
  formatters.dart             # ₹ currency / date formatting
  screens/
    dashboard_screen.dart
    open_positions_screen.dart
    add_position_screen.dart      # Add Stock/MTF/Crypto or Add Option
    position_detail_screen.dart
    edit_lot_screen.dart
    square_off_screen.dart
    closed_trades_screen.dart
    xirr_screen.dart
    backup_restore_screens.dart   # Backup, Restore, More/Settings
.github/workflows/build-apk.yml   # builds & releases the APK automatically
```

Note: this repo intentionally does **not** include the native `android/`
folder. The GitHub Actions workflow regenerates it fresh on every build
(`flutter create . --platforms=android`) using the exact Flutter/Gradle
versions installed on the runner — this avoids version-mismatch build
failures, which are the #1 cause of broken CI builds for hand-edited native
folders. If you want to run the app locally, just run `flutter create .
--platforms=android` once yourself (see below).

## 1. Push this to GitHub

```bash
cd trading_tracker
git init
git add .
git commit -m "Initial commit: Trading Tracker app"
git branch -M main
git remote add origin https://github.com/<your-username>/trading-tracker.git
git push -u origin main
```

## 2. Get the APK — fully automatic

As soon as you push to `main`, the **Build APK** workflow
(`.github/workflows/build-apk.yml`) runs automatically and:

1. Installs Flutter + Java on a GitHub-hosted runner.
2. Regenerates the Android native project.
3. Runs `flutter build apk --release`.
4. Uploads the APK as a downloadable **workflow artifact**.
5. Also attaches it to a new **GitHub Release** (tagged `build-<run number>`)
   so you always have a direct download link.

To get the APK:
- Go to your repo → **Actions** tab → open the latest "Build APK" run →
  download the `trading-tracker-apk` artifact, **or**
- Go to your repo → **Releases** (right sidebar) → download `app-release.apk`
  from the latest release.

You can also trigger a build manually anytime from **Actions → Build APK →
Run workflow** (no code change needed) — useful the first time, before you've
made any commits.

## 3. Install on your phone

1. Download `app-release.apk` (from the Release or the Actions artifact,
   which comes as a zip — unzip it to get the `.apk`) directly on your phone,
   or transfer it via USB/Drive.
2. Open the file. Android will ask you to allow "install from this source"
   the first time — allow it, then tap Install.
3. That's it — the app is fully offline. No sign-in, no server, no internet
   permission is used at runtime.

## 4. Running locally (optional, for development)

You'll need the Flutter SDK installed on your own machine:

```bash
flutter create . --platforms=android --org com.tradingtracker --project-name trading_tracker
flutter pub get
flutter run          # with a device/emulator connected
flutter build apk --release   # to build the APK yourself instead of via CI
```

## Backup & Restore, in plain terms

- **Backup Database** (More → Backup Database): copies the current SQLite
  file to any location you pick on your phone (a folder, Drive, etc.), named
  `trading_tracker_backup_<timestamp>.db`.
- **Restore Database** (More → Restore Database): pick a previously exported
  `.db` file and it fully replaces the app's current data. There's a
  confirmation step since this can't be undone.
- Because everything is a plain file, you can move your whole portfolio to a
  new phone just by copying that one backup file over and restoring it.

## Notes on the data model

- Each symbol you hold is a **Position** (Stock / MTF / Crypto / Options),
  which can have multiple **Lots** (separate purchases).
- **Options** are recorded as Buy + Sell together in one step and land
  directly in Closed Trades — they never appear in Open Positions, matching
  the app spec.
- **XIRR** is computed per asset class and overall from the exact dated cash
  flows of every buy, sell, and (for still-open lots) current value —
  a true money-weighted annualised return, not a simple % gain.
- There's no live market-data feed (this is a fully offline app) — update a
  position's current price manually from the Position Detail screen (the
  price-tag icon in the app bar) whenever you want P&L to reflect the latest
  market price.
