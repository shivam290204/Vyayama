@echo off
set TEMP=E:\temp
set TMP=E:\temp
echo Starting Vyayama Web on port 3000...
echo (Configuration loaded from .env if present, or pass --dart-define arguments)
flutter run -d chrome --web-port=3000 %*
