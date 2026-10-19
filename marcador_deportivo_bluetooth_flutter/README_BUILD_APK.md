# Instrucciones para compilar el APK de Marcador Deportivo Bluetooth

## Requisitos previos
1. Tener instalado Flutter SDK (`flutter --version` >= 3.0.0).
2. Tener instalado Android Studio con el Android SDK y Command-line Tools.

## Pasos para generar el APK:

```bash
# 1. Crear el proyecto Flutter
flutter create marcador_deportivo_bt
cd marcador_deportivo_bt

# 2. Reemplazar los archivos con el código proporcionado
# (pubspec.yaml, lib/main.dart, lib/services/..., AndroidManifest.xml)

# 3. Descargar las dependencias
flutter pub get

# 4. Compilar el APK en modo Release
flutter build apk --release

# El APK generado se encontrará en:
# build/app/outputs/flutter-apk/app-release.apk
```

## Instalación directa en tu teléfono Android:
1. Conecta el teléfono a tu ordenador mediante cable USB.
2. Activa la **Depuración por USB** en las opciones de desarrollador de tu teléfono.
3. Ejecuta en la terminal:
```bash
flutter install
```
¡Listo! La aplicación se instalará en tu teléfono y podrás usarla inmediatamente con tu control Bluetooth selfie y tu parlante.
