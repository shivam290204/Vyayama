# Vyayama Web Launcher with Temp Directory on E: Drive
$env:TEMP = "E:\temp"
$env:TMP = "E:\temp"
Write-Host "Starting Vyayama Web on port 3000..." -ForegroundColor Green
Write-Host "(Configuration loaded from .env if present, or pass --dart-define arguments)" -ForegroundColor Gray
flutter run -d chrome --web-port=3000 @args
