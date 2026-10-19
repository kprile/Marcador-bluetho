#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo 'Instala Flutter estable y Android SDK primero.'; exit 1; }
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
# Keep the custom activity outside of the generated Android scaffold.
cp android/app/src/main/kotlin/cl/marcador/bluetooth/MainActivity.kt "$staging/MainActivity.kt"
flutter create --empty --platforms=android --org cl.marcador --project-name marcador_bluetooth "$staging/app"
cp -R "$staging/app/android/." android/
mkdir -p android/app/src/main/kotlin/cl/marcador/bluetooth
cp "$staging/MainActivity.kt" android/app/src/main/kotlin/cl/marcador/bluetooth/MainActivity.kt
python3 - <<'PY'
from pathlib import Path
p=Path('android/app/build.gradle.kts')
s=p.read_text().replace('cl.marcador.marcador_bluetooth','cl.marcador.bluetooth.v3')
p.write_text(s)
m=Path('android/app/src/main/AndroidManifest.xml')
s=m.read_text().replace('android:label="marcador_bluetooth"','android:label="SCOREBT v3"')
s=s.replace('</manifest>', '<queries><intent><action android:name="android.intent.action.TTS_SERVICE" /></intent></queries></manifest>')
m.write_text(s)
PY
flutter pub get
if [[ "${1:-}" == "--prepare" ]]; then exit 0; fi
flutter analyze
flutter test
flutter build apk --release
