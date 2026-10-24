# Vyayama Web Launcher with Temp Directory on E: Drive
$env:TEMP = "E:\temp"
$env:TMP = "E:\temp"
Write-Host "Starting Vyayama Web on port 3000..." -ForegroundColor Green
if (Test-Path ".env") {
    Write-Host "Loading configuration from .env via --dart-define-from-file..." -ForegroundColor Cyan
    flutter run -d chrome --web-port=3000 --dart-define-from-file=.env @args
} else {
    Write-Host "No .env file found; running in mock fallback mode." -ForegroundColor Yellow
    flutter run -d chrome --web-port=3000 @args
}
