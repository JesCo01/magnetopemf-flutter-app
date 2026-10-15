# App y firmware: versión de ensayo BLE

Esta versión corresponde a la sección 2.3.8 de la tesis. Firmware: [repositorio ESP32](https://github.com/JesCo01/magnetopemf-esp32-firmware), carpeta `MagnetoPEMF/`; app: `lib/`. Ambos extremos usan el protocolo binario de transporte versión 1 descrito aquí. La app anterior, que escribía JSON sin cabecera, no es compatible con este firmware.

## Configuración de ensayo

- GPIO4: PWM rectangular, 10–100 Hz, duty 10–50 %, resolución de 16 bits.
- Ráfaga fija: 15 Hz, ventana de 5 ms, 20 micropulsos de 225 µs en alto y 25 µs en bajo. El porcentaje de PWM rectangular no modifica esa ventana.
- Sesiones de 1–10 minutos; perfil inicial PWM 50 Hz, 10 %, cinco minutos, salida inactiva.
- Los seis perfiles internos son configuraciones de banco. Las rutinas de envolventes triangular/trapezoidal permanecen en el código, pero el intérprete rechaza esos modos en la versión de ensayo.
- Batería: ADC GPIO34, diez muestras de `analogReadMilliVolts`, divisor nominal 68 kΩ/10 kΩ (factor 7,8). El porcentaje es un indicador lineal entre 12 y 16,8 V; no es coulomb counting. `BAT_CAL_GAIN=1` y `BAT_CAL_OFFSET_V=0` son valores nominales, no resultados de una calibración externa. El BMS sigue protegiendo cada celda.

## Conexion BLE directa

1. Encender el ESP32 con el firmware compatible.
2. Activar Bluetooth y conceder los permisos solicitados por la app.
3. Buscar `MAGNETO_TESIS`, conectarse y esperar la sincronizacion del estado.

El firmware actual acepta conexiones directas, sin comando USB `PAIR`, PIN ni ventana de 60 segundos. La app no solicita bonding y el firmware no exige cifrado autenticado para leer o escribir la caracteristica. Guardar un equipo en la app conserva su identificador para reconectarlo; no constituye una autorizacion del telefono en el ESP32.

La app verifica escritura, notificaciones y el descriptor CCCD en Android. Si la tabla GATT esta incompleta, renueva la cache una vez y redescubre los servicios. Solo completa la conexion cuando recibe una respuesta de estado del firmware.

## Transporte y correlación

Cada escritura/notificación lleva una cabecera de seis bytes:

| Byte | Campo |
|---|---|
| 0 | Marcador `0xA5`. |
| 1 | Versión `1`. |
| 2–3 | Identificador de mensaje, entero little-endian de 16 bits. |
| 4 | Secuencia de fragmento, comenzando en cero. |
| 5 | Bits START=1 y END=2; ambos para mensaje de un fragmento. |

El contenido es JSON UTF-8. El identificador cero significa telemetría no solicitada. La respuesta a una orden conserva su identificador; el cliente exige coincidencia de identificador y tipo de respuesta. No se repite automáticamente `start` por falta de ACK.

El tamaño de fragmento es `min(MTU,512)-3`, incluida la cabecera. Las escrituras se serializan con respuesta GATT. El firmware sirve una cola de transmisión sin esperar en bucles bloqueantes; separa los fragmentos al menos cuatro milisegundos. El receptor admite mensajes de hasta 1024 bytes; las órdenes se limitan a 511 bytes. Secuencias fuera de orden, incompletas, con identificadores mezclados o caducadas tras tres segundos no llegan al intérprete. No se admite el formato de texto antiguo `STATS`.

## Estado y sesión

El ESP32 transmite estado JSON completo cada segundo mientras hay una conexion BLE y batería cada cinco segundos. `status` solicita ambos. Los estados incluyen el tiempo programado/restante/transcurrido, el modo en `channels[0].wave`, el identificador de sesión y el motivo de parada.

Inicio, pausa, reanudación y parada esperan confirmación de aplicación durante dos segundos. Una ausencia de respuesta provoca una consulta de estado. La parada cierra el historial tras `stopped` o `IDLE`; la respuesta `stopped` incluye el estado terminal y el tiempo contabilizado por el controlador.

La desconexión invalida las órdenes encoladas de esa conexión y detiene la generación en el ciclo principal. La app conserva el registro sin cerrarlo hasta recuperar el estado terminal. La reconexión no reanuda la generación. Durante la pausa, los reportes conservan los valores editados que aún no se han aplicado.

## Compilación y pruebas

Herramientas utilizadas: Arduino-ESP32 3.3.11, ArduinoJson 7.4.3, Flutter 3.22.1/Dart 3.4.1 y `flutter_blue_plus` 1.30.0. Android utiliza el Gradle wrapper del proyecto y JDK 17; no usar Java 25 con esa configuración.

Desde `APP`:

```text
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug
```

En este equipo también se compiló directamente con el wrapper, desde `APP/android`, usando un JDK 17 portátil y sin modificar la configuración global de Java:

```powershell
$env:JAVA_HOME = 'D:\PROYECTOS\PROYECTO TESIS\tmp\jdk17\jdk-17.0.20.1+1'
$env:Path = "$env:JAVA_HOME\bin;E:\FLUKER_SDK\flutter\bin\mingit\cmd;$env:Path"
.\gradlew.bat assembleDebug
```

El firmware se compila para `esp32:esp32:esp32`. Ejecutar sus pruebas nativas desde la raiz del repositorio independiente del firmware:

```text
python tests/run_tests.py --arduino-json RUTA/ArduinoJson/src
```

Las pruebas de transporte cubren MTU 23, 64, 247 y 512, Unicode, orden, duplicados, pérdida, caducidad y límite de tamaño. Las pruebas de la app usan los proveedores reales con radio e historial sustituidos: rechazo de inicio, sincronización, borradores en pausa, parada confirmada, pérdida de enlace y recuperación sin doble inicio. La prueba de solicitudes usa el correlador y receptor reales para descartar respuestas de otro identificador y consultar `status` tras un timeout. El controlador nativo prueba rechazos sin cambios parciales, temporización y salida detenida.

Las pruebas automatizadas no utilizan el teléfono ni las bobinas. El alcance experimental, incluida la conexion con telefonos fisicos, latencia de desconexión, GPIO4 y calibración externa del divisor, se registra en 2.3.11; este documento no atribuye resultados medidos a las compilaciones o simulaciones.

### Resultado de la revisión del 20 de septiembre de 2026

| Verificación ejecutada | Resultado |
|---|---|
| `flutter analyze --no-pub` | Sin incidencias. |
| `flutter test --no-pub` | 16 pruebas aprobadas: 15 de transporte y sesión, más la prueba vacía heredada. |
| Pruebas nativas del firmware | Aprobadas; 156 órdenes inválidas rechazadas sin cambios parciales, además de órdenes válidas, perfiles, temporización, parada y transporte. |
| Compilación completa para ESP32 clásico | Correcta; 1 165 299 bytes de programa y 44 916 bytes de variables globales. |
| APK Android de depuración con JDK 17 | Compilación correcta; `build/app/outputs/flutter-apk/app-debug.apk`. |

Los registros de esta ejecución se conservan en `../tmp/app_ble_analyze_final.log`, `../tmp/ble_flutter_tests.log`, `../tmp/ble_native_tests.log`, `../tmp/ble_compile_final.log` y `../tmp/ble_apk_jdk17_final.log`. El firmware y el APK deben actualizarse juntos, porque el transporte con cabecera no es compatible con las versiones que intercambiaban JSON sin fragmentación.
