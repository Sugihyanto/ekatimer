# Meditation Timer 1.0.20 — Project Structure

Dokumen ini merekam hasil reconnaissance terhadap source original pada tag
`v1.0.20`. Tidak ada fitur atau UI yang dimodifikasi.

## 1. Identitas source

- Repository resmi: https://github.com/vpnry/ekatimer
- Branch: `main`
- Tag: `v1.0.20`
- Commit: `0acc5e58a93c7b8082d4dab5e440468b4a599197`
- Version: `1.0.20+20`
- Package/namespace Android: `org.tipitakapali.ekatimer`
- Framework: Flutter, dengan implementasi native Android dan iOS untuk fungsi
  yang membutuhkan integrasi platform.
- Lisensi utama: GNU General Public License v3.0 (`LICENSE`).

Evidence bahwa repository ini adalah source resmi:

1. README repository mendeklarasikan URL source itu sendiri.
2. Pemilik repository `vpnry` menautkan profilnya ke `tipitakapali.org`.
3. Package Kotlin dan namespace Android cocok dengan package Google Play,
   `org.tipitakapali.ekatimer`.
4. README, Google Play, dan file `LICENSE` konsisten menyatakan GPLv3.
5. Tag `v1.0.20` menunjuk ke HEAD branch `main` dan source menyatakan
   `version: 1.0.20+20`.

## 2. Build system dan versi toolchain

| Komponen | Versi/konfigurasi |
|---|---|
| Flutter | 3.44.7 stable, revision `84fc5cbb22` |
| Dart | 3.12.2; constraint project `^3.12.0` |
| Gradle wrapper | 9.4.1 (`gradle-9.4.1-all.zip`) |
| Android Gradle Plugin | 9.2.1 |
| Kotlin Android plugin | 2.3.20 |
| Java source/target | Java 17 |
| JDK build | Microsoft OpenJDK 17.0.19+10 LTS |
| compileSdk | 36 |
| targetSdk | 36, berasal dari default Flutter 3.44.7 |
| minSdk | 24, berasal dari default Flutter 3.44.7 |
| NDK | 28.2.13676358, berasal dari default Flutter 3.44.7 |
| Namespace | `org.tipitakapali.ekatimer` |
| applicationId | `org.tipitakapali.ekatimer` |

Konfigurasi utama berada di:

- `pubspec.yaml`
- `android/settings.gradle.kts`
- `android/build.gradle.kts`
- `android/app/build.gradle.kts`
- `android/gradle/wrapper/gradle-wrapper.properties`
- `android/gradle.properties`

Repository mengabaikan `gradlew`, `gradlew.bat`, `gradle-wrapper.jar`,
`local.properties`, dan semua `*.lock`. Oleh karena itu, hasil clone awal hanya
menyertakan `gradle-wrapper.properties`; Flutter membuat file wrapper dan
`local.properties` sebagai file environment yang tidak dilacak Git. Source tag
juga tidak melacak `pubspec.lock`, sehingga resolusi dependency bergantung pada
constraint di `pubspec.yaml` pada saat `flutter pub get` dijalankan.

## 3. Build variants dan signing

Tidak ada product flavor. Variant yang tersedia mengikuti variant standar
Flutter/Android:

- `debug`
- `profile`
- `release`

Debug memakai Android debug keystore standar. APK yang dibangun diverifikasi
memakai APK Signature Scheme v2 dengan sertifikat `CN=Android Debug`.

Release memakai `android/key.properties` dengan field:

- `storePassword`
- `keyPassword`
- `keyAlias`
- `storeFile`

File keystore dan `key.properties` tidak disertakan dalam repository. Karena itu
source dapat dibangun sebagai debug, tetapi belum siap menghasilkan artifact
release resmi tanpa kredensial signing milik distributor.

## 4. Struktur repository

```text
ekatimer/
├── lib/                         # Source aplikasi Dart/Flutter
│   ├── main.dart                # Bootstrap service dan permission
│   ├── app.dart                 # Root app, provider, routing, restore session
│   ├── models/                  # Model timer, session, sound, vibration
│   ├── providers/               # State timer, settings, session/statistics
│   ├── screens/                 # Home, meditation, completion, stats, settings
│   ├── services/                # DB, prefs, alarm, audio, notification, CSV, i18n
│   ├── theme/                   # Theme dan palette
│   ├── utils/                   # Constant dan utility waktu
│   └── widgets/                 # Widget UI reusable dan dialog edit
├── assets/
│   ├── sounds/                  # Delapan file WAV
│   ├── translations/            # JSON terjemahan 15 bahasa
│   ├── quotes/                  # Kutipan pascasession
│   └── images/                  # Launch image
├── android/
│   ├── app/src/main/kotlin/...  # MainActivity dan Android AppWidgetProvider
│   ├── app/src/main/res/        # Layout, icon, preview, dan config widget
│   ├── app/src/main/AndroidManifest.xml
│   └── gradle/                  # Konfigurasi Gradle wrapper
├── ios/                         # Runner, alarm bridge, dan WidgetKit extension
├── macos/, linux/, windows/     # Runner desktop Flutter
├── web/                         # Bootstrap web/PWA
├── test/                        # Widget test dasar
├── docs/, images/               # Store copy, screenshot, helper, sample CSV
├── pubspec.yaml                 # Dependency, version, asset declarations
├── README.md                    # Overview, build, attribution
└── LICENSE                      # GPLv3
```

Jumlah file Dart berdasarkan area utama:

| Area | Jumlah file |
|---|---:|
| models | 5 |
| providers | 3 |
| screens | 6 |
| services | 11 |
| theme | 2 |
| utils | 2 |
| widgets | 7 |

README masih menyebut `history_screen.dart`, tetapi file itu tidak ada pada tag
ini. Riwayat session ditampilkan sebagai bagian dari `StatsScreen`.

## 5. Dependency

Dependency langsung dari `pubspec.yaml` dan versi yang ter-resolve pada build:

| Dependency | Constraint source | Versi build | Fungsi |
|---|---:|---:|---|
| provider | `^6.1.2` | 6.1.5+1 | State management |
| sqflite | `^2.4.1` | 2.4.3 | Database session lokal |
| path_provider | `^2.1.5` | 2.1.6 | Direktori file platform |
| path | `^1.9.1` | 1.9.1 | Path utility |
| shared_preferences | `^2.3.4` | 2.5.5 | Settings dan active-session state |
| audioplayers | `^6.1.0` | 6.8.1 | Playback preview/start/interval |
| vibration | `^3.0.0` | 3.2.0 | Haptic Android/iOS |
| flutter_local_notifications | `^21.0.0` | 21.0.0 | Permission dan local notification service |
| intl | `^0.20.2` | 0.20.3 | Formatting locale/tanggal |
| uuid | `^4.5.1` | 4.6.0 | ID session |
| home_widget | `^0.9.2` | 0.9.3 | Integrasi widget platform |
| wakelock_plus | `^1.2.10` | 1.5.2 | Screen/wakelock saat meditation |
| alarm | `^5.4.1` | 5.10.0 | Exact alarm dan native end bell |
| permission_handler | `^12.0.2` | 12.0.3 | Exact-alarm permission |
| csv | `^8.0.0` | 8.0.0 | Import/export session |
| file_picker | `^10.3.9` | 10.3.10 | Pemilihan CSV/quotes |
| share_plus | `^12.0.2` | 12.0.2 | Share hasil export |
| cupertino_icons | `^1.0.8` | 1.0.9 | Icon iOS-style |

Dev dependency: `flutter_test`, `flutter_lints 6.0.0`, dan
`flutter_launcher_icons 0.14.4`.

Tidak ada dependency yang dinaikkan secara manual. Versi di atas adalah hasil
resolver dari constraint source original pada 13 Agustus 2026.

## 6. Database dan storage

### SQLite

`DatabaseService` memakai `sqflite` dengan database
`meditation_timer.db`, schema version 1, dan tabel `sessions`:

- `id TEXT PRIMARY KEY`
- `startTime INTEGER NOT NULL`
- `endTime INTEGER`
- `durationSeconds INTEGER NOT NULL`
- `targetDurationSeconds INTEGER NOT NULL DEFAULT 0`
- `timerMode TEXT NOT NULL DEFAULT 'timed'`
- `completed INTEGER NOT NULL DEFAULT 1`
- `notes TEXT`

Service menyediakan insert/update/delete, query range tanggal, total dan average
duration, current/longest streak, serta batch import.

### SharedPreferences

`PersistenceService` menyimpan:

- default timer mode dan duration
- screen control, theme, locale
- start/end/interval sound dan volume
- start/end/interval vibration
- session delay
- fixed/recent duration presets
- widget transparency
- user quotes
- state session aktif untuk restore setelah process/app lifecycle berubah

Import/export riwayat memakai CSV melalui `CsvDataService`.

## 7. Timer modes dan session flow

`TimerProvider` adalah state machine dengan state `idle`, `delaying`, `running`,
`paused`, dan `completed`.

- **Timed:** duration 1–600 menit pada UI utama, lalu menghitung end time.
- **End At:** memilih jam/menit; jika waktu sudah lewat, dijadwalkan untuk hari
  berikutnya.
- **Unlimited:** tidak mempunyai end time; service membuat dummy alarm 72 jam
  untuk mekanisme background keep-alive package `alarm`.
- Mendukung delay sebelum mulai, pause/resume, stop, restore active session, dan
  pencatatan hasil ke SQLite.
- Interval sound dan interval vibration diperiksa berdasarkan elapsed minute.
  Pada timed mode, interval yang sama dengan atau lebih panjang dari target
  duration tidak dibunyikan.

## 8. Audio

`AudioService` memakai `audioplayers` dalam `PlayerMode.mediaPlayer` untuk
preview/start/interval sound. End alarm dijadwalkan melalui package `alarm` agar
native alarm tetap dapat berbunyi saat app berada di background.

Asset audio original:

| File | Ukuran byte |
|---|---:|
| Bell.wav | 730,780 |
| Bowl.wav | 639,540 |
| BowlStrong.wav | 1,290,030 |
| GardenBird.wav | 255,210 |
| Gong.wav | 351,570 |
| Sadhu.wav | 550,016 |
| ThreeBowl.wav | 1,611,884 |
| Watch.wav | 882,396 |

README mencatat attribution audio CC0 dan CC BY 4.0. Attribution tersebut harus
dipertahankan bersama kewajiban GPLv3 ketika fork didistribusikan.

## 9. Alarm dan notification

`AlarmService` memakai package `alarm` dengan ID:

- `1001`: Timed
- `1002`: End At
- `1003`: Unlimited keep-alive

Alarm dikonfigurasi dengan optional asset audio, fixed volume, vibration,
warning notification saat process ditutup, full-screen intent Android, dan
notification “Meditation Complete”. Manifest mendeklarasikan exact alarm,
foreground service/media playback, boot complete, wake lock, vibration,
notification, full-screen intent, dan battery-optimization permissions.

`NotificationService` menginisialisasi `flutter_local_notifications` dan meminta
permission. Ia juga menyediakan API notification channel
`meditation_channel`, tetapi pada source v1.0.20 tidak ada pemanggil
`showNotification()` untuk daily reminder. Notification penyelesaian session
yang aktif berasal dari package `alarm`. Commit history juga memuat perubahan
“Remove reminder”; karena itu notification tidak boleh didokumentasikan sebagai
daily reminder yang sudah terbukti aktif tanpa pengujian perangkat.

## 10. Vibration

`VibrationService` memakai plugin `vibration` pada Android dengan pattern:

- short: 100 ms
- medium: 300 ms
- long: 600 ms
- double: `[0, 150, 100, 150]`

Pada iOS, semua pilihan selain `none` dirutekan ke native MethodChannel alarm dan
menjadi satu Taptic pulse agar tetap bekerja ketika layar mati.

## 11. Home screen widget

Android memakai `MeditationTimerWidget` berbasis `AppWidgetProvider` dengan 11
receiver/config:

- Timed: 15m, 30m, 1h, 1.5h, 2h, 2.5h, 3h, 3.5h, 4h
- End At
- Unlimited

Widget adalah shortcut statis yang meneruskan mode/duration ke `MainActivity`
melalui intent. Opsi transparent widget disimpan di SharedPreferences.

## 12. Localization dan resources

`TranslationService` memuat JSON asset dan fallback ke English. Terdapat 15
locale, masing-masing 215 key:

`en`, `vi`, `my`, `si`, `de`, `id`, `zh`, `th`, `hi`, `ne`, `ko`, `ja`,
`km`, `ru`, `lo`.

Resource Android mencakup launcher/launch images, dark/light styles, 12 layout
widget, 11 widget-info XML, dan 11 preview bitmap. Asset Flutter juga mencakup
quotes JSON dan launch image.

## 13. Catatan untuk fork berikutnya

- Pertahankan `LICENSE`, attribution README, dan attribution asset audio.
- Jangan memakai package/signature resmi untuk distribusi tanpa mengganti
  identitas fork sesuai kebutuhan dan tanpa hak dari pemilik merek.
- Jika mendistribusikan binary GPLv3, sediakan corresponding source dan license
  notice yang berlaku.
- Jangan memasukkan keystore, password, atau `key.properties` ke Git.
- Pertimbangkan melacak `pubspec.lock` pada fork aplikasi agar dependency build
  reproducible; source resmi v1.0.20 saat ini mengabaikan semua `*.lock`.
- Warning AGP 9/Kotlin saat build berasal dari legacy variant API dan plugin
  dependency. Jangan meng-upgrade/migrasikan pada tahap original-build ini.

