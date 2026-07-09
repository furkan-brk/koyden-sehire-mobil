# Fiziksel Android cihazda uygulamayi USB uzerinden calistirir.
# adb reverse ile telefonun localhost'u PC'ye tunellenir; boylece
# kampus/kurumsal Wi-Fi'daki client isolation sorun olmaz.
#
# Kullanim (flutter-mobile klasorunden):
#   .\tool\run_device.ps1
#
# Not: Kablo cikarilip takilirsa adb reverse sifirlanir; script'i tekrar calistirin.

$ErrorActionPreference = "Stop"

# adb PATH'te yoksa bilinen SDK konumlarindan bul
$adbCmd = Get-Command adb -ErrorAction SilentlyContinue
if ($adbCmd) {
    $adb = $adbCmd.Source
} else {
    $candidates = @(
        "C:\Android\platform-tools\adb.exe",
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    )
    $adb = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $adb) {
        Write-Host "adb bulunamadi. Android SDK platform-tools kurulu mu?" -ForegroundColor Red
        exit 1
    }
}
Set-Alias -Name adb -Value $adb

$devices = adb devices | Select-String -Pattern "\tdevice$"
if (-not $devices) {
    Write-Host "USB ile bagli Android cihaz bulunamadi. Kabloyu ve USB hata ayiklamayi kontrol edin." -ForegroundColor Red
    exit 1
}

adb reverse tcp:8080 tcp:8080   # Go API
adb reverse tcp:9000 tcp:9000   # MinIO (urun gorselleri)
Write-Host "adb reverse aktif: telefon localhost:8080 -> PC:8080, localhost:9000 -> PC:9000" -ForegroundColor Green

Set-Location $PSScriptRoot\..
flutter run --dart-define=BASE_URL=http://127.0.0.1:8080/api/v1
