# Tracking en Segundo Plano - CycleTracker

## ✅ Cambios Implementados

### 1. Nuevas Dependencias
- `flutter_background_service`: Para ejecutar código en segundo plano
- `wakelock_plus`: Para mantener la CPU activa durante tracking
- `flutter_local_notifications`: Para mostrar notificación persistente

### 2. Permisos Android Añadidos
```xml
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### 3. Servicio de Background (`lib/services/background_service.dart`)
- **Foreground Service**: Mantiene la app activa en segundo plano
- **Notificación Persistente**: Muestra progreso del tracking (distancia, tiempo, velocidad)
- **Recolección de Ubicación**: Continúa obteniendo posiciones GPS cada 2 segundos
- **Persistencia de Datos**: Guarda datos en SharedPreferences como backup

### 4. LocationService Mejorado
- **WakeLock**: Mantiene la CPU activa durante tracking
- **Integración con Background Service**: Coordina el tracking entre foreground y background
- **Filtrado de Outliers Mejorado**: Mejor manejo de saltos de ubicación

### 5. Funcionalidades del Background Service
- ✅ Tracking continuo cuando la pantalla se apaga
- ✅ Notificación persistente con métricas en tiempo real
- ✅ Cálculo de distancia, tiempo y velocidad en background
- ✅ Manejo de pausa/reanudación
- ✅ Backup de datos en SharedPreferences
- ✅ Filtrado de movimientos mínimos (> 2 metros)

## 📱 Cómo Funciona

### Cuando inicias tracking:
1. Se activa el WakeLock para mantener la CPU
2. Se inicia el Background Service como Foreground Service
3. Se muestra una notificación persistente
4. Tanto el servicio principal como el background recolectan ubicaciones

### Cuando apagas la pantalla:
1. El Background Service continúa funcionando
2. La notificación se actualiza con las métricas actuales
3. Los datos se guardan en SharedPreferences
4. El tracking NO se interrumpe

### Cuando vuelves a encender la pantalla:
1. La app principal sincroniza con los datos del background
2. El mapa se actualiza con la ruta completa
3. Las métricas reflejan todo el recorrido

## 🧪 Para Probar

### 1. Compilar e Instalar
```bash
flutter clean
flutter pub get
flutter run -d [DEVICE_ID]
```

### 2. Probar Funcionalidad
1. **Iniciar tracking** en la app
2. **Verificar notificación** persistente aparece
3. **Apagar pantalla** del dispositivo
4. **Caminar/moverse** por unos minutos
5. **Encender pantalla** y ver que:
   - La ruta se actualiza con todos los puntos
   - Las métricas incluyen todo el recorrido
   - No hay "saltos" en la ubicación

### 3. Verificar en Logcat
```bash
adb logcat | grep -E "(BackgroundService|LocationService)"
```

## ⚡ Optimizaciones Implementadas

### Background Service
- **Timer de 2 segundos**: Balance entre precisión y batería
- **Filtro de movimiento mínimo**: Solo registra movimientos > 2 metros
- **Notificación de baja prioridad**: No interrumpe al usuario
- **Manejo de errores**: Continúa funcionando aunque haya errores puntuales

### LocationService Principal
- **WakeLock**: Solo activo durante tracking
- **Filtrado de outliers mejorado**: Ignora saltos improbables
- **Coordinación**: Funciona junto al background service sin duplicar datos

### Notificación Inteligente
- **Actualización en tiempo real**: Muestra distancia, tiempo y velocidad
- **Baja prioridad**: No hace sonido ni vibra
- **Persistente**: No se puede descartar accidentalmente

## 🔧 Configuración Adicional (Opcional)

### Para mejor rendimiento en producción:
1. **Reducir frecuencia de logging** en `debugMode = false`
2. **Ajustar intervalo del timer** en `background_service.dart` (línea 180)
3. **Optimizar filtros de ubicación** según necesidades específicas

### Para debugging:
- Mantener `debugMode = true` en `LocationService`
- Usar `adb logcat` para monitorear funcionamiento
- Verificar notificaciones en el panel de Android

## 📋 Notas Importantes

1. **Permisos**: En Android 10+ el usuario debe conceder permiso de "ubicación en segundo plano" manualmente
2. **Batería**: El sistema puede limitar apps en background si no están en la whitelist
3. **Foreground Service**: Requiere notificación persistente por regulaciones de Android
4. **iOS**: Requiere configuración adicional específica (no implementada aún)

Los cambios están listos para probar. La app ahora debería mantener el tracking activo incluso cuando la pantalla se apaga.