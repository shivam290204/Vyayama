# Vyayama Web Launcher with Temp Directory on E: Drive
$env:TEMP = "E:\temp"
$env:TMP = "E:\temp"
flutter run -d chrome --web-port=3000
