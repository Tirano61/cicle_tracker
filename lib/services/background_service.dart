import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de background para continuar tracking cuando la app está en segundo plano
class BackgroundLocationService {
  static const String _channelId = 'location_tracking_channel';
  static const String _channelName = 'Location Tracking';
  static const int _notificationId = 1001;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Inicializar el servicio de background
  static Future<void> initializeService() async {
    try {
      final service = FlutterBackgroundService();

      // Verificar si ya está configurado
      bool isRunning = await service.isRunning();
      if (isRunning) {
        return; // Ya está configurado
      }

      // Configurar notificaciones
      await _initializeNotifications();

      // Configurar el servicio
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: _channelId,
          initialNotificationTitle: 'CycleTracker',
          initialNotificationContent: 'Tracking de ubicación iniciado',
          foregroundServiceNotificationId: _notificationId,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
    } catch (e) {
      print('[BackgroundService] Error initializing service: $e');
      rethrow;
    }
  }

  /// Configurar las notificaciones locales
  static Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    // Crear canal de notificación en Android
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Canal para notificaciones de tracking de ubicación',
      importance: Importance.low,
      enableVibration: false,
      playSound: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Iniciar el servicio de tracking en background
  static Future<bool> startTracking() async {
    try {
      final service = FlutterBackgroundService();
      
      // Verificar si el servicio ya está corriendo
      bool isRunning = await service.isRunning();
      if (isRunning) {
        print('[BackgroundService] Service already running');
        return true;
      }

      // Inicializar si no está configurado
      await initializeService();

      // Iniciar el servicio
      await service.startService();
      print('[BackgroundService] Service started successfully');
      return true;
    } catch (e) {
      print('[BackgroundService] Error starting service: $e');
      return false;
    }
  }

  /// Detener el servicio de tracking
  static Future<void> stopTracking() async {
    try {
      final service = FlutterBackgroundService();
      service.invoke('stop');
    } catch (e) {
      print('[BackgroundService] Error stopping service: $e');
    }
  }

  /// Pausar/reanudar tracking
  static Future<void> pauseTracking() async {
    try {
      final service = FlutterBackgroundService();
      service.invoke('pause');
    } catch (e) {
      print('[BackgroundService] Error pausing service: $e');
    }
  }

  static Future<void> resumeTracking() async {
    try {
      final service = FlutterBackgroundService();
      service.invoke('resume');
    } catch (e) {
      print('[BackgroundService] Error resuming service: $e');
    }
  }

  /// Enviar datos de tracking al servicio principal
  static Future<void> sendTrackingData(Map<String, dynamic> data) async {
    try {
      final service = FlutterBackgroundService();
      service.invoke('tracking_data', data);
    } catch (e) {
      print('[BackgroundService] Error sending tracking data: $e');
    }
  }
}

/// Punto de entrada para el servicio de background (Android)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();

    bool isTracking = false;
    bool isPaused = false;
    Timer? locationTimer;
    Position? lastPosition;
    double totalDistance = 0.0;
    DateTime? startTime;
    DateTime? pauseTime;
    Duration totalPausedTime = Duration.zero;

    // Escuchar comandos del servicio principal
    service.on('stop').listen((event) {
      try {
        locationTimer?.cancel();
        service.stopSelf();
      } catch (e) {
        print('[BackgroundService] Error stopping service: $e');
      }
    });

    service.on('pause').listen((event) {
      try {
        isPaused = true;
        pauseTime = DateTime.now();
        _updateNotification('CycleTracker - Pausado', 'Tracking pausado');
      } catch (e) {
        print('[BackgroundService] Error pausing service: $e');
      }
    });

    service.on('resume').listen((event) {
      try {
        if (isPaused && pauseTime != null) {
          totalPausedTime += DateTime.now().difference(pauseTime!);
        }
        isPaused = false;
        pauseTime = null;
        _updateNotification('CycleTracker - Activo', 'Tracking en progreso...');
      } catch (e) {
        print('[BackgroundService] Error resuming service: $e');
      }
    });

    // Iniciar tracking de ubicación
    isTracking = true;
    startTime = DateTime.now();
    
    await _updateNotification('CycleTracker - Activo', 'Tracking en progreso...');

    // Timer para obtener ubicación cada 2 segundos
    locationTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!isTracking || isPaused) return;

      try {
        // Verificar permisos
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          print('[BackgroundService] Location permission denied');
          return;
        }

        // Obtener posición actual
        Position currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
          ),
        );

        // Calcular distancia si hay posición anterior
        if (lastPosition != null) {
          double distance = Geolocator.distanceBetween(
            lastPosition!.latitude,
            lastPosition!.longitude,
            currentPosition.latitude,
            currentPosition.longitude,
          );
          
          // Solo agregar si el movimiento es significativo (> 2 metros)
          if (distance > 2.0) {
            totalDistance += distance;
            lastPosition = currentPosition;

            // Calcular tiempo transcurrido
            Duration elapsed = DateTime.now().difference(startTime!);
            if (pauseTime != null) {
              elapsed -= DateTime.now().difference(pauseTime!);
            }
            elapsed -= totalPausedTime;

            // Calcular velocidad promedio
            double avgSpeed = totalDistance > 0 && elapsed.inSeconds > 0 
                ? (totalDistance / 1000) / (elapsed.inSeconds / 3600) 
                : 0.0;

            // Actualizar notificación con datos actuales
            String distanceText = '${(totalDistance / 1000).toStringAsFixed(2)} km';
            String timeText = '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
            String speedText = '${avgSpeed.toStringAsFixed(1)} km/h';
            
            await _updateNotification(
              'CycleTracker - $distanceText',
              'Tiempo: $timeText | Velocidad: $speedText',
            );

            // Enviar datos al servicio principal (si está disponible)
            try {
              await BackgroundLocationService.sendTrackingData({
                'latitude': currentPosition.latitude,
                'longitude': currentPosition.longitude,
                'distance': totalDistance,
                'elapsed': elapsed.inSeconds,
                'speed': currentPosition.speed * 3.6, // convertir a km/h
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              });
            } catch (e) {
              print('[BackgroundService] Error sending data to main service: $e');
            }

            // Guardar datos en SharedPreferences como backup
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('bg_total_distance', totalDistance);
              await prefs.setInt('bg_elapsed_seconds', elapsed.inSeconds);
              await prefs.setDouble('bg_last_lat', currentPosition.latitude);
              await prefs.setDouble('bg_last_lon', currentPosition.longitude);
              await prefs.setInt('bg_last_update', DateTime.now().millisecondsSinceEpoch);
            } catch (e) {
              print('[BackgroundService] Error saving to SharedPreferences: $e');
            }
          }
        } else {
          lastPosition = currentPosition;
        }
      } catch (e) {
        print('[BackgroundService] Error getting location: $e');
      }
    });
  } catch (e) {
    print('[BackgroundService] Fatal error in onStart: $e');
  }
}

/// Punto de entrada para iOS background
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // Para iOS, implementar lógica similar pero con limitaciones de iOS
  return true;
}

/// Actualizar la notificación persistente
Future<void> _updateNotification(String title, String body) async {
  const androidDetails = AndroidNotificationDetails(
    'location_tracking_channel',
    'Location Tracking',
    channelDescription: 'Canal para notificaciones de tracking de ubicación',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    showWhen: false,
    enableVibration: false,
    playSound: false,
  );

  const notificationDetails = NotificationDetails(android: androidDetails);

  try {
    await FlutterLocalNotificationsPlugin().show(
      1001,
      title,
      body,
      notificationDetails,
    );
  } catch (e) {
    print('[BackgroundService] Error updating notification: $e');
  }
}