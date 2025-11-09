# 🧪 Debug del Compass - Instrucciones de Testing

## 📋 **Estado Actual del Debugging**

### ✅ **Logs implementados:**
- 🧭 `CompassBar - Rotation received` - Entrada al widget
- 🎬 `CompassBar - Animated rotation` - Animación en progreso  
- 🎨 `CompassBarPainter - paint() called` - Inicio del dibujado
- 📐 `CompassBarPainter - Normalized rotation` - Rotación normalizada
- 📍 `Point X: angle=Y°, angleFromNorth=Z°, displayAngle=W°` - Cálculo de cada punto cardinal
- ✅ `X visible at x=Y, isActive=Z` - Puntos cardinales visibles
- 🗺️ `Map rotation changed` - Rotación del mapa (si está disponible)
- 📡 `GPS Heading updated` - Heading del GPS recibido
- 🔄 `[LocationService] GPS Heading` - Procesamiento del heading
- 📍 `[LocationPos]` - Posición con heading incluido

### 🎯 **Cambio implementado:**
- **ANTES**: La brújula usaba `_mapRotation` (rotación del mapa manual)
- **AHORA**: La brújula usa `_currentHeading` (heading del GPS real)

## 🧪 **Cómo probar:**

### **1. Iniciar el tracking**
1. Abrir la app CycleTracker
2. Presionar **▶️ INICIAR** para comenzar tracking
3. **Observar logs iniciales** en la terminal

### **2. Simular movimiento en emulador**
1. **Abrir Extended Controls** del emulador (⋯ botón)
2. Ir a **Location** 
3. **Cambiar coordenadas** manualmente
4. **Rotar el dispositivo** o usar puntos con diferentes direcciones
5. **Observar logs** de heading

### **3. Testing en dispositivo real**
1. **Caminar/mover** el dispositivo físicamente
2. **Cambiar dirección** de movimiento
3. **Observar** si la barra de brújula se actualiza
4. **Verificar logs** en tiempo real

## 📊 **Logs esperados durante movimiento:**

```
📡 GPS Heading updated: 45.0° (previous: 0.0°)
🧭 CompassBar - Rotation received: 45.0 degrees  
🎬 CompassBar - Animated rotation: 45.0 degrees
🎨 CompassBarPainter - paint() called with rotation: 45.0 degrees
📐 CompassBarPainter - Normalized rotation: 45.0 degrees
🧭 Drawing cardinal points...
  📍 Point N: angle=0.0°, angleFromNorth=315.0°, displayAngle=-45.0°
  📍 Point NE: angle=45.0°, angleFromNorth=0.0°, displayAngle=0.0°
    ✅ NE visible at x=200.0, isActive=true
  📍 Point E: angle=90.0°, angleFromNorth=45.0°, displayAngle=45.0°
    ✅ E visible at x=250.0, isActive=false
```

## 🔍 **Posibles problemas a detectar:**

### **❌ Problema 1: Heading no llega**
**Síntomas:** No aparecen logs `📡 GPS Heading updated`
**Causa:** GPS no está proporcionando heading válido
**Solución:** Verificar que `p.heading` esté en rango 0-360°

### **❌ Problema 2: Heading llega pero compass no se actualiza**  
**Síntomas:** Logs `📡 GPS Heading updated` aparecen pero no hay logs `🧭 CompassBar`
**Causa:** `setState` no está actualizando el widget
**Solución:** Verificar el listener de metrics

### **❌ Problema 3: Compass se actualiza pero no dibuja correctamente**
**Síntomas:** Logs llegan hasta `🎨 CompassBarPainter` pero puntos cardinales no aparecen
**Causa:** Error en cálculos del painter
**Solución:** Revisar lógica de `angleFromNorth` y `displayAngle`

### **❌ Problema 4: Heading inválido**
**Síntomas:** Logs muestran `GPS Heading: -1.0° -> invalid°`  
**Causa:** GPS reporta heading inválido (fuera de 0-360°)
**Solución:** Normal en emulador, probar en dispositivo real

## 🎯 **Testing específico:**

### **Test 1: Verificar recepción de heading**
```
1. Iniciar tracking
2. Buscar logs: [LocationService] GPS Heading: X° -> Y°
3. ✅ PASS: Y° está entre 0-360°
4. ❌ FAIL: Y° es "invalid" constantemente
```

### **Test 2: Verificar actualización de compass**
```  
1. Con tracking activo
2. Buscar logs: 📡 GPS Heading updated: X°
3. Inmediatamente después: 🧭 CompassBar - Rotation received: X degrees
4. ✅ PASS: Los valores X coinciden
5. ❌ FAIL: No hay correlación entre ambos logs
```

### **Test 3: Verificar cálculos de puntos cardinales**
```
1. Con heading = 45° (NE)
2. Buscar logs de Point NE: displayAngle=0.0°, isActive=true
3. Buscar logs de Point N: displayAngle=-45.0°, isActive=false  
4. ✅ PASS: NE es activo, otros son relativos correctamente
5. ❌ FAIL: Cálculos incorrectos
```

## 🛠️ **Comandos de debugging:**

### **Ver logs en tiempo real:**
```bash
adb logcat -s flutter
```

### **Filtrar solo compass:**
```bash  
adb logcat -s flutter | findstr -i "compass\|heading\|Point"
```

### **Ver solo GPS:**
```bash
adb logcat -s flutter | findstr -i "GPS\|LocationPos"
```

## 📱 **Resultados esperados:**

### **🎯 Comportamiento correcto:**
1. **Heading se actualiza** cuando cambia dirección de movimiento
2. **Punto cardinal activo** cambia según heading
3. **Animación suave** de 250ms entre cambios  
4. **Indicador central** apunta hacia la dirección de movimiento
5. **Logs consistentes** muestran la cadena completa de updates

### **🚨 Indicadores de problemas:**
1. **Compass no se mueve** durante cambios de dirección
2. **Heading siempre "invalid"** en logs
3. **Logs se cortan** en algún punto de la cadena
4. **Compass usa mapRotation** en lugar de GPS heading
5. **Puntos cardinales incorrectos** (ej: E activo cuando vamos al N)

---

**Estado**: 🔧 **DEBUGGING EN PROGRESO**  
**Logs**: ✅ **Implementados y funcionando**  
**Siguiente paso**: 🧪 **Testing con movimiento real**