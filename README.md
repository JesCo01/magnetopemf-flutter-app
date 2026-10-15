# MagnetoPEMF: aplicacion Flutter

Aplicacion del prototipo de tesis MagnetoPEMF para conectar un telefono con el ESP32 mediante Bluetooth Low Energy (BLE), configurar la senal, controlar sesiones y guardar pacientes e historial localmente.

El firmware se mantiene en un repositorio independiente: [magnetopemf-esp32-firmware](https://github.com/JesCo01/magnetopemf-esp32-firmware).

## Requisitos

- Entorno utilizado por el proyecto: Flutter 3.22.1 y Dart 3.4.1.
- Android SDK y JDK 17 para compilar Android.
- Telefono Android con BLE para comprobar la conexion con el prototipo.
- Firmware compatible con el transporte BLE version 1.

Se incluyen las carpetas de otras plataformas de Flutter, pero la integracion con el prototipo se centra en Android. Su presencia no implica validacion BLE en iOS, web o escritorio.

## Instalacion y ejecucion

Desde la raiz de este repositorio:

```powershell
flutter pub get
flutter devices
flutter run -d ID_DEL_DISPOSITIVO
```

Sustituir `ID_DEL_DISPOSITIVO` por el identificador del telefono mostrado por `flutter devices`.

Para generar un APK de depuracion:

```powershell
flutter build apk --debug
```

El archivo se genera en `build/app/outputs/flutter-apk/app-debug.apk`. La configuracion actual de `release` utiliza la firma de depuracion; requiere configurar una firma propia antes de distribuir una version de produccion.

## Conexion con el ESP32

1. Cargar el firmware compatible en el ESP32.
2. Abrir su consola USB a 115200 baudios con terminador de linea.
3. Con el prototipo en reposo y sin telefono conectado, enviar `PAIR` para abrir la ventana de vinculacion de 60 segundos.
4. Activar Bluetooth en el telefono, abrir la app y conceder los permisos solicitados.
5. Buscar el equipo `MAGNETO_TESIS` y conectarse. Introducir en el dialogo de Android el PIN de seis digitos mostrado en la consola USB.
6. Esperar a que la app sincronice el estado antes de iniciar una sesion.

Las conexiones posteriores reutilizan el vinculo guardado. Para revocarlo, enviar `UNPAIR` por USB con el prototipo en reposo y sin conexion BLE, y olvidar el equipo en Android.

La desconexion detiene la salida en el firmware; reconectar no reanuda automaticamente una sesion. La app y el firmware deben usar la misma version de transporte. Consultar [BLE_IMPLEMENTACION.md](BLE_IMPLEMENTACION.md) para el protocolo y el alcance de las comprobaciones.

## Estructura

- `lib/core/`: tema, constantes y rutas.
- `lib/data/`: transporte BLE y repositorios.
- `lib/domain/models/`: modelos de datos.
- `lib/presentation/`: pantallas, proveedores de estado y componentes.
- `test/`: pruebas de transporte, solicitudes y control de sesiones.
- `android/`, `ios/`, `linux/`, `macos/`, `web/` y `windows/`: proyectos de plataforma.

El historial se almacena con Hive; los pacientes y preferencias se conservan localmente. No se necesita un servidor para estas funciones.

## Validacion

```powershell
flutter analyze
flutter test
```

Las pruebas automatizadas simulan la radio y no sustituyen la comprobacion con telefono, ESP32 y circuito fisico.

## Archivos del repositorio

Se conservan `pubspec.lock`, `.metadata`, el codigo de plataforma y las pruebas. Los archivos generados (`build/`, `.dart_tool/`, caches), la configuracion del IDE y `android/local.properties` permanecen locales y se excluyen mediante `.gitignore`. No incluir claves de firma, archivos `.env` ni exportaciones de pacientes.
