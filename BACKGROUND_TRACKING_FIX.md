# Corrección de Bloqueo en Tracking de Background

## Problema identificado
La aplicación se bloqueaba cuando se apagaba y encendía la pantalla del dispositivo durante el tracking GPS.

## Causas del problema

1. **Doble inicialización del servicio**: El servicio de background se inicializaba tanto en `main()` como en `startTracking()`, causando conflictos.

2. **Manejo inadecuado del WakeLock**: No se verificaba el estado del WakeLock antes de habilitarlo/deshabilitarlo.

3. **Falta de manejo del ciclo de vida**: La app no manejaba adecuadamente las transiciones entre primer plano y segundo plano.

4. **Manejo de errores insuficiente**: Los errores en el servicio de background no se capturaban correctamente.

## Soluciones implementadas

### 1. Manejo mejorado del ciclo de vida de la app

**Archivo**: `lib/main.dart`

- Agregado `WidgetsBindingObserver` para monitorear cambios en el ciclo de vida
- Implementado `didChangeAppLifecycleState()` para manejar transiciones de estado
- Logs para debugging de estados de la aplicación

```dart
class _CycleAppState extends State<CycleApp> with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Manejo de estados: paused, resumed, detached, inactive, hidden
  }
}
```

### 2. Prevención de doble inicialización

**Archivo**: `lib/services/background_service.dart`

- Verificación del estado del servicio antes de configurarlo
- Prevención de re-configuración si ya está ejecutándose
- Manejo robusto de errores en la inicialización

```dart
static Future<void> initializeService() async {
  try {
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    if (isRunning) {
      return; // Ya está configurado
    }
    // ... configuración solo si es necesario
  } catch (e) {
    print('[BackgroundService] Error initializing service: $e');
    rethrow;
  }
}
```

### 3. WakeLock con verificación de estado

**Archivo**: `lib/services/location_service.dart`

- Verificación del estado del WakeLock antes de habilitarlo
- Manejo seguro del WakeLock al detener el tracking
- Prevención de errores por WakeLock ya activo

```dart
// Activar WakeLock solo si no está activo
if (!await WakelockPlus.enabled) {
  await WakelockPlus.enable();
}

// Desactivar WakeLock solo si está activo
WakelockPlus.enabled.then((isEnabled) {
  if (isEnabled) {
    WakelockPlus.disable();
  }
}).catchError((e) => print('Error: $e'));
```

### 4. Manejo robusto de errores en background service

**Archivo**: `lib/services/background_service.dart`

- Try-catch completo en el punto de entrada `onStart()`
- Manejo de errores en listeners de eventos
- Logs detallados para debugging
- Operaciones asíncronas con await para notificaciones

```dart
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();
    // ... lógica del servicio con manejo de errores
  } catch (e) {
    print('[BackgroundService] Fatal error in onStart: $e');
  }
}
```

### 5. Verificación inteligente del estado del servicio

**Archivo**: `lib/services/location_service.dart`

- Verificación si el servicio ya está corriendo antes de iniciarlo
- Solo iniciar servicio de background si es necesario
- Logs informativos del estado del servicio

```dart
final service = FlutterBackgroundService();
bool isRunning = await service.isRunning();
if (!isRunning) {
  await BackgroundLocationService.startTracking();
}
```

## Beneficios de las correcciones

1. **Estabilidad mejorada**: Eliminación de crashes al cambiar el estado de la pantalla
2. **Uso eficiente de recursos**: Prevención de servicios duplicados
3. **Debugging mejorado**: Logs detallados para identificar problemas
4. **Manejo de errores robusto**: Captura y manejo de excepciones
5. **Ciclo de vida controlado**: Respuesta adecuada a cambios de estado de la app

## Archivos modificados

- `lib/main.dart`: Manejo del ciclo de vida de la app
- `lib/services/background_service.dart`: Mejoras en robustez y manejo de errores
- `lib/services/location_service.dart`: WakeLock inteligente y verificación de estado

## Testing recomendado

1. Iniciar tracking GPS
2. Apagar pantalla del dispositivo
3. Mover el dispositivo por diferentes ubicaciones
4. Encender pantalla
5. Verificar que:
   - La app no se bloquea
   - Todos los puntos GPS fueron registrados
   - La notificación persistente se actualiza correctamente
   - El WakeLock funciona adecuadamente

## Configuración de debug

Para habilitar logs detallados, modificar en `LocationService`:

```dart
bool debugMode = true; // Cambiar a false para producción
```

Con `debugMode = true`, se registrarán:
- Posiciones GPS detalladas
- Errores de polling
- Estados del servicio
- Transiciones del ciclo de vida