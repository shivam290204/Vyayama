@echo off
set TEMP=E:\temp
set TMP=E:\temp
echo Starting Vyayama Web on port 3000...
if exist .env (
  echo Loading configuration from .env via --dart-define-from-file...
  flutter run -d chrome --web-port=3000 --dart-define-from-file=.env %*
) else (
  echo No .env file found, starting in fallback mode...
  flutter run -d chrome --web-port=3000 %*
)
