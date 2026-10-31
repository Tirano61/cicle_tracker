import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Reloj superpuesto al mapa. Mantiene su propio Timer para no forzar
/// rebuilds de toda la pantalla de tracking cada segundo.
class MapClock extends StatefulWidget {
  const MapClock({super.key});

  @override
  State<MapClock> createState() => _MapClockState();
}

class _MapClockState extends State<MapClock> {
  static final DateFormat _format = DateFormat('HH:mm');
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      // Solo reconstruir cuando cambia el minuto mostrado
      if (now.minute != _now.minute || now.hour != _now.hour) {
        setState(() => _now = now);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, color: Colors.white, size: 20),
          const SizedBox(width: 6),
          Text(
            _format.format(_now),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
