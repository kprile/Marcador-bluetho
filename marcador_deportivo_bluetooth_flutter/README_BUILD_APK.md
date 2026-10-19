# SCOREBT · Android v3

Referencia visual: rama v.3 de kprile/Marcador-Deportivo-iaestudio,
commit fdc8121f6f0dbe80f6ca00542682737f5eec119a.

## Cambios v3

- Marcador limpio a pantalla completa, tanteos más grandes y menú flotante.
- Se conserva el motor corregido y probado de la v2, el historial y el control HID.
- Se respeta la voz elegida manualmente. Si desaparece, se avisa en lugar de
  reemplazarla silenciosamente. Se puede elegir Automática explícitamente.
- El APK solo ofrece voces españolas instaladas offline. Yolanda Online de un
  navegador no se descarga ni se distribuye como una voz nativa Android.
- Nombre SCOREBT v3, identificador cl.marcador.bluetooth.v3: puede instalarse
  junto a v1 y v2 y guarda sus datos por separado.
- No se modifica la rama main ni las ramas v.1 y v.2.

## Por qué el primer APK no coincidía con AI Studio

AI Studio ejecuta el proyecto React/TypeScript en `src/components`. Su pantalla
“Proyecto Flutter” genera textos Dart desde `src/data/flutterProjectFiles.ts`.
Esos textos contienen una aplicación simplificada y no reproducen la aplicación
React. El primer repositorio Android contenía precisamente esa exportación.
La app Android implementa directamente la interfaz de referencia en Flutter y utiliza
Android para captura HID, almacenamiento y síntesis de voz.

## Cambios

- Identidad SCOREBT, azul oscuro, amarillo/celeste, números Barlow Condensed
  incorporados al APK, división vertical, indicador de saque, juegos y sets.
- Diseño adaptable a horizontal y vertical; inversión visual de lados y modo
  de pantalla completa. Invertir lados no altera la asignación de equipos del control.
- Selector de deporte y nombres, individuales/dobles, primer sacador y receptor
  inicial de ping-pong dobles. Al mejor de 1/3/5/7 sets o juegos.
- Tenis y pádel: 0/15/30/40, iguales, ventaja o No-Ad/punto de oro, sets a seis
  con diferencia de dos y tie-break a siete con diferencia de dos en 6–6.
- Ping-pong: juegos a once con diferencia de dos, saque cada dos puntos y cada
  uno desde 10–10. Alternancia del primer sacador entre juegos. Rotación de cuatro
  jugadores en dobles y cambio de recepción a cinco en el juego decisivo.
- Ganador, bloqueo de puntos posteriores y deshacer incluso tras el final.
  Se reconstruye el estado desde el registro completo de puntos.
- Avisos de punto de juego/set/partido, juego/set/ganador, saque y cambios de lado.
- Voces españolas **instaladas sin conexión**; velocidad configurable y acceso
  a ajustes de Android. Nunca se selecciona deliberadamente una voz de red.
- Guardado local por punto, recuperación del partido actual, historial de cien
  partidos archivados y visualización del actual. No duplica finales al deshacer.
- Diagnóstico de eventos Android DOWN/UP, código, scan code, repetición y dispositivo.
  Tocar una señal DOWN permite aprender el botón y filtrar por el dispositivo.
- Una pulsación = equipo 1; dos = equipo 2; tres = deshacer. Se espera una ventana
  configurable después de la última pulsación antes de confirmar un punto.
- Se cancelan pulsaciones pendientes al salir, abrir un diálogo o corregir.
  Los diálogos, el diagnóstico y el segundo plano no aceptan puntos por control.
- Pruebas automatizadas de reglas, guardado, agrupación de pulsaciones y pantallas.

## Compilar

Flutter estable 3.35+ y Android SDK/Java 17/Python 3:

```bash
cd marcador_deportivo_bluetooth_flutter
bash tool/bootstrap.sh
```

`bootstrap.sh` genera el andamiaje Android oficial y conserva el puente Kotlin.
Ejecuta análisis, pruebas y `flutter build apk --release`. El APK usa la firma
local de desarrollo de la plantilla Flutter: adecuado para pruebas, no una
versión lista para Play Store. Para una distribución estable se debe configurar
un almacén de claves propio. Los APK de ejecuciones distintas pueden requerir
desinstalar el anterior si cambia la clave de desarrollo; eso borra sus datos.

GitHub Actions compila la rama `v.3` y entrega **Cancha-v3-Android**. También
publica imágenes de pruebas de interfaz en **Cancha-v3-vistas**.
No hay llamadas a modelos de IA, servidores ni necesidad de claves de API.

## Prueba en cancha

1. Emparejar control y parlante desde los ajustes Bluetooth de Android.
2. Instalar una voz española offline en los ajustes de síntesis de voz.
3. Abrir Diagnóstico BT y pulsar el control: verificar DOWN y UP separados.
4. Tocar una señal DOWN para usar ese botón y activar el filtro por dispositivo.
5. Probar una/dos/tres pulsaciones; ajustar la ventana en Voz y Parlante.
6. Confirmar salida al parlante y probar todo sin conexión a internet.

El control se desactiva al abrir nuevamente la app para evitar pulsaciones
involuntarias. Reactivarlo en Voz y Parlante o reaprenderlo en Diagnóstico BT.
La app mantiene la pantalla encendida mientras está visible y debe permanecer
en primer plano durante el partido. La salida de audio la elige Android.

## Alcance y pruebas físicas pendientes

- No todos los disparadores selfie son HID o envían teclas aprovechables. Algunos
  agrupan pulsaciones, usan controles multimedia especiales o solo funcionan con
  cámara. No se garantiza compatibilidad universal ni hay soporte BLE/GATT genérico.
- Validar control concreto, latencia, rebotes, reconexión, botón mantenido y
  conexión simultánea con parlante. El filtro de dispositivo debe revisarse tras
  cambiar de control o teléfono.
- Validar voces offline por fabricante, salida A2DP, volumen y modo de ahorro.
- Validar legibilidad al sol, distancias, accesibilidad y pantalla real de cancha.
- Orden de saque fijo durante el partido. No permite reelegirlo al comienzo de
  cada set/juego ni todas las variantes de torneo. Pádel individual es recreativo.
- Tie-break a siete en todos los sets; sin super tie-break final, Star Point,
  sets cortos ni sistema de aceleración de ping-pong.
- iPhone pendiente: falta implementar puentes iOS y verificar controles físicos.
- Varios teléfonos sincronizados quedan para una etapa futura; no hay red ni servidor.

Fuentes de reglas usadas para las modalidades implementadas:
https://www.padelfip.com/wp-content/uploads/2025/12/FIP_Rules-of-Padel.pdf
https://www.itftennis.com/en/about-us/governance/rules-and-regulations/?type=rules
https://www.ittf.com/statutes/

Fuente Barlow Condensed incorporada bajo SIL Open Font License. Ver
`assets/fonts/OFL.txt`.
