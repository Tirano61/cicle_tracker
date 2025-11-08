# Solución: Error de Tipo de Servicio Foreground

## Problema identificado

La aplicación fallaba al iniciar el servicio en segundo plano con el siguiente error:

```
MissingForegroundServiceTypeException: Starting FGS without a type
```

## Causa del problema

En Android API 35 (Android 14+) es obligatorio especificar el tipo de servicio foreground. El plugin `flutter_background_service` no define automáticamente el tipo correcto en el AndroidManifest.xml.

## Error específico

```
E/AndroidRuntime( 6794): java.lang.RuntimeException: Unable to create service id.flutter.flutter_background_service.BackgroundService: android.app.MissingForegroundServiceTypeException: Starting FGS without a type
```

## Solución implementada

### 1. Agregado tipo de servicio foreground

**Archivo**: `android/app/src/main/AndroidManifest.xml`

Se agregó la declaración del servicio con el tipo específico para ubicación:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    
    <!-- ... otros elementos ... -->
    
    <application>
        <!-- ... otros elementos ... -->
        
        <!-- Servicio de background para tracking de ubicación -->
        <service
            android:name="id.flutter.flutter_background_service.BackgroundService"
            android:foregroundServiceType="location"
            android:exported="false"
            tools:replace="android:exported" />
            
        <!-- ... otros elementos ... -->
    </application>
</manifest>
```

### 2. Elementos clave de la solución

- **`android:foregroundServiceType="location"`**: Especifica que es un servicio de ubicación
- **`xmlns:tools="http://schemas.android.com/tools"`**: Namespace para herramientas de fusión de manifiestos
- **`tools:replace="android:exported"`**: Resuelve conflictos con el manifiesto del plugin

## Tipos de servicio foreground disponibles

Para referencia futura, los tipos de servicio foreground disponibles son:

- `location` - Para servicios de ubicación GPS
- `camera` - Para servicios de cámara
- `microphone` - Para servicios de audio/micrófono
- `mediaProjection` - Para captura de pantalla
- `phoneCall` - Para llamadas telefónicas
- `mediaPlayback` - Para reproducción de medios
- `dataSync` - Para sincronización de datos
- `health` - Para servicios de salud
- `remoteMessaging` - Para mensajería remota
- `systemExempted` - Para servicios exentos del sistema
- `shortService` - Para servicios de corta duración
- `specialUse` - Para casos especiales

## Permisos relacionados

Asegurar que estos permisos estén presentes:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

## Verificación de la solución

1. ✅ **Compilación exitosa**: La aplicación se compila sin errores
2. ✅ **Servicio definido**: El tipo de servicio está especificado correctamente
3. ✅ **Conflictos resueltos**: Los conflictos de manifiesto están solucionados

## Testing recomendado

Para verificar que la solución funciona:

1. Instalar la aplicación: `flutter install`
2. Iniciar el tracking GPS
3. Verificar que no aparece el error `MissingForegroundServiceTypeException`
4. Comprobar que la notificación persistente aparece
5. Apagar/encender pantalla para verificar funcionamiento continuo

## Notas importantes

- Esta solución es específica para Android API 35+
- El tipo `location` es apropiado para apps de tracking GPS
- El `tools:replace` es necesario para resolver conflictos con plugins
- Mantener todos los permisos de ubicación necesarios

## Archivos modificados

- `android/app/src/main/AndroidManifest.xml`: Agregado servicio con tipo correcto

## Referencias

- [Android Foreground Services](https://developer.android.com/develop/background-work/services/foreground-services)
- [Foreground Service Types](https://developer.android.com/develop/background-work/services/foreground-services/types-required)
- [Flutter Background Service Plugin](https://pub.dev/packages/flutter_background_service)