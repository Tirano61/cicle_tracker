import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/live_tracking_data.dart';
import 'background_service.dart';

/// Clean, single-definition LocationService.
class LocationService {
  LocationService._privateConstructor();
  static final LocationService _instance = LocationService._privateConstructor();
  factory LocationService() => _instance;

  StreamSubscription<Position>? _positionSub;
  Timer? _timer;
  final StreamController<LiveTrackingData> _controller = StreamController<LiveTrackingData>.broadcast();

  LiveTrackingData _state = LiveTrackingData();
  final Distance _distance = const Distance();

  final LocationSettings _locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
  );

  // Tunable thresholds
  // Reduce threshold to capture more points on emulators/devices with sparse updates
  double _minMetersToAdd = 0.2; // 0.2 meter
  Timer? _pollTimer; // periodic polling to increase sample density
  // Debug flag to enable prints during testing (toggle for emulator tests)
  bool debugMode = true;
  // When debugMode is true we'll lower thresholds and poll faster

  Stream<LiveTrackingData> get trackingStream => _controller.stream;
  LiveTrackingData get currentData => _state;

  Future<bool> checkAndRequestPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<bool> startTracking() async {
    if (_state.isTracking) return true;
    final ok = await checkAndRequestPermissions();
    if (!ok) return false;

    try {
      // Activar WakeLock para mantener la CPU activa durante tracking
      if (!await WakelockPlus.enabled) {
        await WakelockPlus.enable();
      }
      
      // Solo iniciar el servicio de background si no está corriendo
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        await BackgroundLocationService.startTracking();
      }

      final pos = await Geolocator.getCurrentPosition();
      final initial = LatLng(pos.latitude, pos.longitude);
      if (debugMode) {
        // ignore: avoid_print
        print('[LocationService] startTracking initial=${initial.latitude.toStringAsFixed(6)},${initial.longitude.toStringAsFixed(6)}');
      }
      _state = _state.copyWith(
        isTracking: true,
        isPaused: false,
        startTime: DateTime.now(),
        lastUpdateTime: DateTime.now(),
        currentLocation: initial,
        routePoints: [initial],
        distanceKm: 0.0,
      );

      _controller.add(_state);

      _positionSub = Geolocator.getPositionStream(locationSettings: _locationSettings).listen(_onPosition, onError: (e) {
        if (debugMode) {
          // ignore: avoid_print
          print('[LocationService] Position stream error: $e');
        }
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

      // Adjust thresholds for debug mode to increase sample density
      final pollMs = debugMode ? 700 : 1000;
      if (debugMode) {
        _minMetersToAdd = 0.0; // accept even tiny movements in debug
      }

      // Start a short-polling loop to get more frequent positions (improves emulator & sparse streams)
      // We call getCurrentPosition every pollMs and feed it into the same handler.
      _pollTimer = Timer.periodic(Duration(milliseconds: pollMs), (_) async {
        try {
          final p2 = await Geolocator.getCurrentPosition();
          _onPosition(p2);
        } catch (e) {
          if (debugMode) {
            // ignore: avoid_print
            print('[LocationService] Polling error: $e');
          }
        }
      });

      return true;
    } catch (e) {
      if (debugMode) {
        // ignore: avoid_print
        print('[LocationService] Error starting tracking: $e');
      }
      return false;
    }
  }

  void pauseTracking() {
    if (!_state.isTracking || _state.isPaused) return;
    
    // Pausar el servicio de background
    BackgroundLocationService.pauseTracking();
    
    _state = _state.copyWith(isPaused: true, pauseStartTime: DateTime.now());
    _controller.add(_state);
  }

  void resumeTracking() {
    if (!_state.isTracking || !_state.isPaused) return;
    
    // Reanudar el servicio de background
    BackgroundLocationService.resumeTracking();
    
    var additional = Duration.zero;
    if (_state.pauseStartTime != null) {
      additional = DateTime.now().difference(_state.pauseStartTime!);
    }
    _state = _state.copyWith(
      isPaused: false,
      pauseStartTime: null,
      totalPausedTime: _state.totalPausedTime + additional,
    );
    _controller.add(_state);
  }

  void stopTracking() {
    // Detener el servicio de background
    BackgroundLocationService.stopTracking();
    
    // Desactivar WakeLock solo si está activo
    WakelockPlus.enabled.then((isEnabled) {
      if (isEnabled) {
        WakelockPlus.disable();
      }
    }).catchError((e) {
      if (debugMode) {
        // ignore: avoid_print
        print('[LocationService] Error disabling WakeLock: $e');
      }
    });
    
    _positionSub?.cancel();
    _positionSub = null;
    _timer?.cancel();
    _timer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (debugMode) {
      // ignore: avoid_print
      print('[LocationService] stopTracking');
    }
    _state = _state.copyWith(isTracking: false, isPaused: false);
    _controller.add(_state);
  }

  void resetTracking() {
    stopTracking();
    _state = LiveTrackingData();
    _controller.add(_state);
  }

  Future<LatLng?> getCurrentLocation() async {
    try {
      final ok = await checkAndRequestPermissions();
      if (!ok) return null;
      final p = await Geolocator.getCurrentPosition();
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _positionSub?.cancel();
    _timer?.cancel();
    _pollTimer?.cancel();
    _controller.close();
  }

  // Internal tick to update elapsed time
  void _tick() {
    if (!_state.isTracking || _state.startTime == null) return;
    final now = DateTime.now();
    var totalElapsed = now.difference(_state.startTime!);
    var currentPause = Duration.zero;
    if (_state.isPaused && _state.pauseStartTime != null) {
      currentPause = now.difference(_state.pauseStartTime!);
    }
    final real = totalElapsed - _state.totalPausedTime - currentPause;
    _state = _state.copyWith(elapsedTime: real);
    _controller.add(_state);
  }

  void _onPosition(Position p) {
    if (!_state.isTracking || _state.isPaused) return;
    final point = LatLng(p.latitude, p.longitude);
    final last = _state.routePoints.isNotEmpty ? _state.routePoints.last : null;

    double addMeters = 0.0;
    if (last != null) {
      addMeters = _distance.as(LengthUnit.Meter, last, point);
    }

    // Outlier filtering: ignore improbable jumps based on reported accuracy and speed
    final accuracy = p.accuracy; // meters
    final speedKmh = (p.speed * 3.6).clamp(0.0, 300.0);
    bool isOutlier = false;
    // If accuracy is very poor and speed is low, and the jump is much larger than accuracy * 3 (+ buffer), drop
    // NOTE: relax this rule for high-speed readings (they can legitimately cover large distances between fixes)
    if (accuracy > 0 && addMeters > (accuracy * 3.0 + 30.0) && speedKmh < 25.0) {
      isOutlier = true;
    }
    // If device reports very poor accuracy overall, avoid accepting fixes when speed is low
    if (accuracy > 100.0 && speedKmh < 10.0 && addMeters > 20.0) {
      isOutlier = true;
    }
    // If speed is essentially zero but we see a sudden large jump, likely a bad fix
    if (speedKmh < 3.0 && addMeters > 50.0) {
      isOutlier = true;
    }

    if (isOutlier) {
      if (debugMode) {
        try {
          // ignore: avoid_print
          print('[LocationService] Ignored outlier addMeters=${addMeters.toStringAsFixed(1)} acc=${accuracy.toStringAsFixed(1)} speed=${speedKmh.toStringAsFixed(1)}');
        } catch (_) {}
      }
      return;
    }

    // DEBUG: show incoming fix details
    if (debugMode) {
      try {
        // ignore: avoid_print
        print('[LocationPos] lat=${point.latitude.toStringAsFixed(6)} lon=${point.longitude.toStringAsFixed(6)} acc=${p.accuracy.toStringAsFixed(1)}m speed=${(p.speed*3.6).toStringAsFixed(1)}km/h addMeters=${addMeters.toStringAsFixed(2)} minReq=${_minMetersToAdd.toStringAsFixed(2)}');
      } catch (_) {}
    }

    if (last == null || addMeters >= _minMetersToAdd) {
      final newPoints = List<LatLng>.from(_state.routePoints)..add(point);
      final newDistance = _state.distanceKm + (addMeters / 1000.0);
      final speedKmh = (p.speed * 3.6).clamp(0.0, 200.0);
      final newSpeeds = List<double>.from(_state.speeds)..add(speedKmh);
      final filteredSpeeds = newSpeeds.where((s) => s >= 0.5).toList();
      final avg = filteredSpeeds.isEmpty ? 0.0 : filteredSpeeds.reduce((a, b) => a + b) / filteredSpeeds.length;
      final maxSpeed = newSpeeds.isEmpty ? speedKmh : _state.maxSpeedKmh > speedKmh ? _state.maxSpeedKmh : speedKmh;

      _state = _state.copyWith(
        currentLocation: point,
        lastUpdateTime: DateTime.now(),
        routePoints: newPoints,
        distanceKm: newDistance,
        speeds: newSpeeds,
        currentSpeedKmh: speedKmh,
        averageSpeedKmh: avg,
        maxSpeedKmh: maxSpeed,
      );

      _controller.add(_state);
    }
  }
}