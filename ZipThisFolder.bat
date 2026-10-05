@echo off
setlocal

rem ==================================================
rem Konfigurasi
rem ==================================================

set "LIMIT=17000000"
set "THREADS=20"
set "FILECOUNT=0"
set "SEVENZIP=C:\Program Files\7-Zip\7z.exe"

rem ==================================================
rem Nama archive:
rem NamaFolder YYYY-MM-DD HHMMSS.7z
rem ==================================================

for %%I in (.) do set "DIRNAME=%%~nxI"

for /F "delims=" %%D in (
    'powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HHmmss'"'
) do set "TIMESTAMP=%%D"

set "OUTPUT=..\%DIRNAME% %TIMESTAMP%.7z"

rem ==================================================
rem Periksa instalasi 7-Zip
rem ==================================================

if not exist "%SEVENZIP%" (
    echo.
    echo ERROR: 7-Zip tidak ditemukan:
    echo "%SEVENZIP%"
    pause
    exit /B 1
)

rem ==================================================
rem Pilihan tingkat kompresi
rem ==================================================

echo.
echo ==========================================
echo   Kompres Current Folder dengan 7-Zip
echo ==========================================
echo.
echo Jumlah thread CPU: %THREADS%
echo.
echo [1] Paling Kecil
echo     Kompresi tertinggi dan paling lambat
echo.
echo [2] Seimbang
echo     Kecepatan dan ukuran yang seimbang
echo.
echo [3] Sangat Cepat
echo     Proses cepat, ukuran archive lebih besar
echo.

rem ==================================================
rem Countdown 5 detik
rem Otomatis memilih opsi 1
rem X adalah tombol internal untuk timeout
rem ==================================================

set "TIMER=5"

:COUNTDOWN
choice /C 123X /N /T 1 /D X /M "Pilih [1/2/3] - otomatis [1] dalam %TIMER% detik: "

if errorlevel 4 goto TICK
if errorlevel 3 goto FAST
if errorlevel 2 goto BALANCED
if errorlevel 1 goto SMALLEST

:TICK
set /A TIMER-=1

if %TIMER% GTR 0 goto COUNTDOWN

echo.
echo Waktu habis. Otomatis memilih [1] Paling Kecil.
goto SMALLEST

rem ==================================================
rem Parameter kompresi dengan 20 thread
rem ==================================================

:SMALLEST
set "OPTION=-mx=9 -m0=LZMA2 -mmt=%THREADS% -ms=on"
set "MODE=Paling Kecil"
goto START

:BALANCED
set "OPTION=-mx=5 -m0=LZMA2 -mmt=%THREADS% -ms=on"
set "MODE=Seimbang"
goto START

:FAST
set "OPTION=-mx=3 -m0=LZMA2 -mmt=%THREADS% -ms=on"
set "MODE=Sangat Cepat"
goto START

rem ==================================================
rem Mulai kompresi
rem ==================================================

:START
echo.
echo ==========================================
echo   Memulai Kompresi
echo ==========================================
echo Mode    : %MODE%
echo Threads : %THREADS%
echo Sumber  : %CD%
echo Output  : %OUTPUT%
echo.

"%SEVENZIP%" a -t7z %OPTION% "%OUTPUT%" ".\*"

set "RESULT=%ERRORLEVEL%"

echo.

if %RESULT% EQU 0 (
    echo ==========================================
    echo Kompresi selesai.
    echo File: %OUTPUT%
    echo ==========================================
) else if %RESULT% EQU 1 (
    echo ==========================================
    echo Kompresi selesai dengan WARNING.
    echo Periksa informasi dari 7-Zip di atas.
    echo File: %OUTPUT%
    echo ==========================================
) else (
    echo ==========================================
    echo ERROR: Proses kompresi gagal.
    echo Kode error 7-Zip: %RESULT%
    echo ==========================================
)

pause
endlocal