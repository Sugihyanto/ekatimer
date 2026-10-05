# Meditation Timer

Meditation Timer is a distraction-free Flutter meditation timer distributed
under the GNU General Public License version 3 (GPLv3).

This repository contains an independently distributed modified version of
[Meditation Timer](https://github.com/vpnry/ekatimer), based on upstream tag
`v1.0.20` (`0acc5e58a93c7b8082d4dab5e440468b4a599197`). It is not an official
Meditation Timer release and no upstream endorsement is implied. The upstream project
was inspired by Trevor Slocum's
[Meditation Assistant](https://codeberg.org/tslocum/meditationassistant).

## Release identity

- Application name: `Meditation Timer`
- Android application ID and namespace: `org.tipitakapali.ekatimer`
- Release version: `1.0.28+28`
- Android minimum SDK: 24
- Android compile/target SDK used for the release: 36

There is one Android application ID only. OEM Dual Apps/App Clone features use
Android's user/profile isolation; this project does not create a second package.
Availability of cloning is controlled by the device manufacturer.

## Main features

- Timed, End At, and Unlimited meditation sessions
- Start, interval, and completion bells, vibration, alarms, and notifications
- Android quick-start home-screen widgets
- Multiple meditation profiles with isolated sessions and statistics
- Optional Quality score from `0.0` through `5.0`, including fractional stars
- Optional full-length session notes
- Overview, session, weekly, monthly, and yearly reports
- Weekly/monthly Calendar and Bar Chart views with a Quality visibility toggle
- CSV and Excel export
- JSON backup for profiles and sessions
- Merge or Overwrite options when importing backup/CSV data
- Light/dark themes and multilingual UI resources

## Source layout

- `lib/` — Flutter application source
- `android/` — Android application, widgets, and build scripts
- `ios/`, `linux/`, `macos/`, `web/`, `windows/` — inherited Flutter platform projects
- `assets/` — sounds, translations, quotes, and runtime images
- `test/` — automated Flutter tests
- `tools/` — release packaging tools

Android is the primary validated release target for version 1.0.28. Other
platform folders are included as source but were not release-qualified as part
of this Android source export.

## Build

Recommended release environment:

- Flutter 3.44.x stable (Dart 3.12.x)
- Java 17
- Android SDK 36
- Gradle 9.4.1 through the included wrapper

From the project root:

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test --no-pub
flutter build apk --release --target-platform android-arm64 --split-per-abi --no-pub
```

The exact Dart/Flutter dependency versions and package hashes are recorded in
`pubspec.lock`.

On Windows, enable Developer Mode before preparing a clean checkout so Flutter
can create the symlinks required by plugins.

### Signing

No keystore, signing password, `key.properties`, or `local.properties` is
included in the public source package. If `android/key.properties` is absent,
the release APK remains unsigned. Use a debug build for local sideloading; do
not publish it or substitute a debug certificate for the production key.

See [SOURCE_RELEASE.md](SOURCE_RELEASE.md) for build and publication details.

## Data backup scope

The JSON backup contains profiles, the active profile identifier, and all
meditation sessions. It does not contain general settings such as timer
defaults, sounds, vibration, theme, locale, widgets, schedules, or an active
timer. CSV import/export is scoped to the active profile.

## Attribution

Project and asset attributions are recorded in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and are also shown inside the
application. Individual third-party components and assets remain under their
respective licenses.

## License

The application source is distributed under the
[GNU General Public License version 3](LICENSE). Preserve the license, existing
notices, attribution, and source availability when redistributing modified or
binary versions.

This program is provided without warranty; see the GPLv3 text for details.

## Upstream source

- Meditation Timer: https://github.com/vpnry/ekatimer
- Baseline: tag `v1.0.20`, commit
  `0acc5e58a93c7b8082d4dab5e440468b4a599197`
- Meditation Assistant: https://codeberg.org/tslocum/meditationassistant
