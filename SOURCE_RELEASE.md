# Meditation Timer 1.0.28 — GPL source release

## Snapshot

- Product: Meditation Timer
- Version: `1.0.28+28`
- Source snapshot date: `2026-08-24`
- Android application ID: `org.tipitakapali.ekatimer`
- License: GNU General Public License version 3; see `LICENSE`
- Upstream: Meditation Timer `v1.0.20`
- Upstream commit: `0acc5e58a93c7b8082d4dab5e440468b4a599197`

This is an independently distributed version modified from Meditation Timer. The
changes and their date are recorded in `CHANGELOG.md`. This is not an official
Meditation Timer release and no upstream endorsement is implied.

This archive contains the preferred source form for modifying this release,
the Android/platform project files, tests, runtime assets, locked dependency
metadata, and scripts used to build and package it.

## Rebuilding the Android application

Install Flutter 3.44.x stable, Java 17, and Android SDK 36. Then run:

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test --no-pub
flutter build apk --release --target-platform android-arm64 --split-per-abi --no-pub
```

The Android project includes Gradle wrapper 9.4.1. Android Gradle Plugin 9.2.1
and Kotlin 2.3.20 are declared in `android/settings.gradle.kts`.

Windows requires Developer Mode (or equivalent symlink permission) when
preparing a clean Flutter checkout that uses plugins.

The source package intentionally does not include Flutter, the Android SDK,
Java, downloaded Gradle distributions, or downloaded pub packages. Exact Dart
package versions, source URLs, and integrity hashes are recorded in
`pubspec.lock` and are restored by `flutter pub get`.

## Release signing

Signing keys are private deployment credentials and are not part of the public
source archive. To create a production-signed build, create
`android/key.properties` locally with your keystore path and credentials. Never
commit or publish that file or the keystore.

Without `android/key.properties`, Gradle leaves the release APK unsigned. Use a
debug build for local sideloading. Do not submit a debug-signed artifact to
Google Play or register its certificate as a permanent production/upload key.

## Archive generation

Run the release script from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools/create_source_release.ps1
```

The script creates the following files under `dist/`:

- `Meditation Timer-v1.0.28-GPL-source.zip`
- `Meditation Timer-v1.0.28-GPL-source.zip.sha256.txt`

The ZIP contains `SOURCE_MANIFEST.sha256`, which records a SHA-256 digest for
every included file except the manifest itself.

The archive excludes:

- `.git`, editor state, local reports, and store/marketing documents
- `.dart_tool`, `.pub-cache`, Gradle caches, and platform-generated files
- `build`, `dist`, coverage, APK, AAB, IPA, and other compiled outputs
- `local.properties`, `key.properties`, keystores, certificates, and secrets
- historical sample session data and unused/unlicensed draft assets

## Publication checklist

1. Publish this source archive from the same release page or download location
   as the corresponding binary.
2. Publish the accompanying `.sha256.txt` checksum.
3. Keep `LICENSE`, `README.md`, `CHANGELOG.md`, this file, and
   `THIRD_PARTY_NOTICES.md` intact.
4. State clearly that this is a modified version of Meditation Timer rather than an
   official upstream build.
5. After creating a permanent public repository, add its exact release/tag URL
   to the application and release page. Do not present the upstream repository
   as the source of modifications that it does not contain.
6. Retain `org.tipitakapali.ekatimer`; do not create another application ID
   merely to support OEM Dual Apps/App Clone.
7. Confirm the redistribution basis for every non-code asset before production
   publication, especially assets identified in `THIRD_PARTY_NOTICES.md`.
8. Commit the reviewed source snapshot and create a `v1.0.28` tag in the public
   repository so the archive and public history refer to the same source.

This document is an engineering release checklist, not legal advice.
