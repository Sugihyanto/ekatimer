# ekaTimer 1.0.20 — Original Build Report

Tanggal pelaksanaan: 13–14 Agustus 2026 (Asia/Jakarta)

## Ringkasan

| Item | Hasil |
|---|---|
| Source | https://github.com/vpnry/ekatimer |
| Branch/tag | `main`, `v1.0.20` |
| Commit | `0acc5e58a93c7b8082d4dab5e440468b4a599197` |
| License | GNU GPLv3 |
| Build original | **SUCCESS** |
| Command final | `android\gradlew.bat assembleDebug --console=plain` |
| Gradle result | `BUILD SUCCESSFUL in 2m 23s` |
| APK | `build/app/outputs/flutter-apk/app-debug.apk` |
| APK size | 193,077,612 byte (184.13 MiB) |
| APK SHA-256 | `A1B54149BD7B820DC99A336C6E588C76656B4C9D968D816FB5F8510F09616D41` |
| Package | `org.tipitakapali.ekatimer` |
| versionName | `1.0.20` |
| versionCode | `20` |
| Device install | **NO DEVICE** saat tahap instalasi |
| Source modification | Tidak ada perubahan fitur/UI/source |
| Static analysis | `dart analyze`: **No issues found** |

## 1. Repository dan clone

Folder tujuan `ekatimer` belum ada, sehingga repository di-clone ke subfolder
baru tanpa menghapus atau menimpa root workspace yang sudah mempunyai Git kosong.

State segera setelah clone:

```text
origin  https://github.com/vpnry/ekatimer.git (fetch)
origin  https://github.com/vpnry/ekatimer.git (push)
branch  main
tag     v1.0.20
HEAD    0acc5e58a93c7b8082d4dab5e440468b4a599197
status  main...origin/main, clean
```

`v1.0.20` menunjuk ke HEAD `main`. Commit terkait version berada pada history:

```text
0acc5e5 (HEAD, tag: v1.0.20) add Apple and Android app store links
847eef7 Build version 1.0.20+20
b996d2c Trailing for large system font-size
```

## 2. Build environment

| Komponen | Nilai |
|---|---|
| OS/shell | Windows PowerShell |
| Flutter | 3.44.7 stable |
| Dart | 3.12.2 |
| Gradle | 9.4.1 |
| Android Gradle Plugin | 9.2.1 |
| Kotlin plugin | 2.3.20 |
| Java | Microsoft OpenJDK 17.0.19+10 LTS |
| compileSdk | 36 |
| targetSdk | 36 |
| minSdk | 24 |
| NDK | 28.2.13676358 |
| Android SDK | platform 36, build-tools 36.0.0 |

Flutter SDK yang digunakan:

```text
C:\Users\sugih\Documents\Codex\android-build-tools\flutter-sdk-3.44.7\flutter
```

Android SDK dan JDK:

```text
C:\Users\sugih\Documents\Codex\android-build-tools\android-sdk
C:\Users\sugih\Documents\Codex\android-build-tools\jdk-17.0.19+10
```

## 3. Build commands

Dependency setup:

```powershell
flutter.bat pub get
```

Bootstrap build:

```powershell
flutter.bat build apk --debug --no-pub
```

Verifikasi final memakai Gradle wrapper sesuai prioritas permintaan:

```powershell
cd android
.\gradlew.bat assembleDebug --console=plain
```

Output akhir:

```text
> Task :app:assembleDebug
BUILD SUCCESSFUL in 2m 23s
550 actionable tasks: 23 executed, 527 up-to-date
```

## 4. APK metadata

Hasil `aapt2 dump badging`:

```text
package: name='org.tipitakapali.ekatimer'
versionCode='20'
versionName='1.0.20'
compileSdkVersion='36'
minSdkVersion:'24'
targetSdkVersion:'36'
application-label:'ekaTimer'
```

APK path absolut:

```text
C:\Users\sugih\OneDrive\Documents\ChatGPT\Eka Timer\ekatimer\build\app\outputs\flutter-apk\app-debug.apk
```

SHA-256:

```text
A1B54149BD7B820DC99A336C6E588C76656B4C9D968D816FB5F8510F09616D41
```

Signing verification:

```text
Verifies
Verified using APK Signature Scheme v2: true
Number of signers: 1
Signer certificate: C=US, O=Android, CN=Android Debug
```

Ini APK debug, bukan artifact release resmi dan bukan pengganti signature Google
Play.

## 5. Installation result

ADB sempat mendeteksi perangkat berikut sebelum APK selesai:

```text
RRCT600NJDM  device  model:SM_G990E
```

Ketika tahap instalasi dimulai, `adb devices -l` sudah tidak menampilkan device.
`adb start-server` dan pemeriksaan ulang setelah jeda tetap menghasilkan daftar
kosong. Sesuai instruksi, APK tidak di-install bila tidak ada device.

Hasil final:

```text
DEVICE INSTALL: NO DEVICE
```

Tidak ada aplikasi existing yang di-uninstall dan tidak ada tindakan terhadap
signature, Play Integrity, DRM, atau proteksi platform.

## 6. Verification original app

### Verifikasi build/static yang berhasil

| Fungsi | Evidence pada source/build | Status |
|---|---|---|
| Timed timer | `TimerMode.timed`, duration/end time, alarm ID 1001 | Source/build verified |
| End At | End time hari ini/berikutnya, alarm ID 1002 | Source/build verified |
| Unlimited | Elapsed timer dan keep-alive alarm ID 1003 | Source/build verified |
| Bell/audio | `audioplayers`, package `alarm`, 8 WAV dibundel ke APK | Source/build verified |
| Interval bell | `_checkIntervalSounds()` dan interval settings | Source/build verified |
| Vibration | none/short/medium/long/double service | Source/build verified |
| History | SQLite `sessions`, list pada StatsScreen | Source/build verified |
| Statistics | Total, average, streak, daily/weekly/monthly/yearly | Source/build verified |
| Settings | SharedPreferences dan SettingsScreen | Source/build verified |
| Notification | Permission service dan completion notification dari alarm | Source/build verified |
| Widget | 11 Android widget receivers/config | Source/build verified |
| Localization | 15 locale × 215 key, English fallback | Source/build verified |

`dart analyze` berhasil dengan output:

```text
Analyzing ekatimer...
No issues found!
```

### Batas verifikasi runtime

Karena device hilang dari ADB sebelum instalasi, hal berikut **belum diuji secara
runtime** pada APK hasil build:

- launch/render UI di perangkat
- countdown Timed, End At, Unlimited
- playback start/end/interval bell saat foreground/background/screen off
- pattern vibration aktual
- exact alarm dan completion notification
- persistence/history/statistics setelah session nyata
- semua halaman settings dan semua locale
- pemasangan serta tap semua widget

Keberhasilan compile dan keberadaan implementasi source tidak dianggap sebagai
bukti bahwa semua interaksi perangkat di atas sudah lolos.

Widget test original (`test/widget_test.dart`) dicoba, tetapi runner Flutter
tidak menghasilkan output dan tidak selesai; proses dihentikan. Hasil test itu
dicatat **INCONCLUSIVE**, bukan PASS. Tidak ada source yang diubah untuk membuat
test tersebut lewat.

## 7. Problems encountered dan fixes

### 7.1 Flutter SDK Git ownership

Masalah:

```text
fatal: detected dubious ownership in repository at ...flutter
```

Fix environment:

```powershell
git config --global --add safe.directory C:/Users/sugih/Documents/Codex/android-build-tools/flutter-sdk-3.44.7/flutter
```

Source ekaTimer tidak diubah.

### 7.2 Windows symlink/Developer Mode

Masalah saat `flutter pub get`:

```text
Building with plugins requires symlink support.
Please enable Developer Mode...
```

Fix environment: target Windows desktop Flutter dinonaktifkan sementara selama
build Android. Developer Mode Windows tidak diubah. Setelah pekerjaan, target
Windows desktop diaktifkan kembali.

### 7.3 Missing generated Gradle wrapper files

Clone resmi hanya melacak `gradle-wrapper.properties`; `.gitignore` mengabaikan
wrapper script/JAR. Flutter membangkitkan:

- `android/gradlew`
- `android/gradlew.bat`
- `android/gradle/wrapper/gradle-wrapper.jar`
- `android/local.properties`

Semua tetap merupakan file environment yang ignored, bukan perubahan source.

### 7.4 First Gradle bootstrap sangat lama

Bootstrap pertama harus mengunduh Gradle 9.4.1-all, dependency Maven, dan
mengompilasi plugin/JNI untuk beberapa ABI di checkout OneDrive. Command runner
mencapai timeout 10 menit, tetapi child Gradle tetap menyelesaikan APK. Build
ulang langsung dengan wrapper kemudian memberikan exit code 0 dan
`BUILD SUCCESSFUL` dalam 2m23s.

### 7.5 Dart analyzer state folder

Run pertama gagal karena sandbox menolak pembuatan
`%LOCALAPPDATA%\.dartServer\.plugin_manager`. Run ulang di luar sandbox berhasil
dan menghasilkan `No issues found!`; ini masalah environment, bukan error source.

### 7.6 Build warnings

Build mengeluarkan warning, tanpa error:

- `android.builtInKotlin=false` dan `android.newDsl=false` deprecated untuk AGP
  10 mendatang.
- Legacy variant APIs (`applicationVariants`, `libraryVariants`, dan lainnya)
  digunakan oleh Flutter/plugin.
- Beberapa plugin masih mengaplikasikan Kotlin Gradle Plugin dan perlu migrasi
  ke AGP built-in Kotlin pada versi Flutter mendatang.
- Gradle melaporkan deprecated features yang akan incompatible dengan Gradle 10.

Tidak dilakukan upgrade dependency atau migrasi build karena tahap ini harus
mempertahankan source original 1.0.20.

## 8. Files created

- `PROJECT_STRUCTURE.md`
- `BUILD_REPORT.md`

Selain dua dokumen tersebut, hanya ada artifact/build cache/generated files yang
diabaikan Git. Tidak ada source Dart, Kotlin, manifest, resource, atau dependency
constraint yang diedit.

## 9. Legal/license

- File `LICENSE` GPLv3 dan attribution README dipertahankan utuh.
- Attribution audio CC0/CC BY 4.0 tidak dihapus.
- Jika fork/binary didistribusikan, kewajiban GPLv3 untuk corresponding source,
  license notice, dan hak penerima harus dipenuhi.
- Keystore, credential, dan signature resmi tidak tersedia dan tidak dicoba
  untuk diakali.

