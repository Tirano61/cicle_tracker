import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../models/cycling_session.dart';

class SessionDetailScreen extends StatelessWidget {
  final CyclingSession session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sesión ${DateFormat('dd/MM/yyyy').format(session.startTime)}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información general
            _buildInfoCard(context),

            const SizedBox(height: 16),

            // Métricas detalladas
            _buildMetricsGrid(context),

            const SizedBox(height: 16),

            // Mapa de la ruta
            if (session.routePoints.isNotEmpty) _buildRouteMap(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final scheme = Theme.of(context).colorScheme;
  final onSurface60 = scheme.onSurface.withAlpha((0.6 * 255).round());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información de la Sesión',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.calendar_today, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inicio', style: TextStyle(fontSize: 12, color: onSurface60)),
                      Text(dateFormat.format(session.startTime)),
                    ],
                  ),
                ),
              ],
            ),
            if (session.endTime != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.flag, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Final', style: TextStyle(fontSize: 12, color: onSurface60)),
                        Text(dateFormat.format(session.endTime!)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, color: scheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Duración', style: TextStyle(fontSize: 12, color: onSurface60)),
                      Text(_formatDuration(session.duration)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Métricas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildMetricTile(
                  context,
                  'Distancia',
                  '${session.distanceKm.toStringAsFixed(2)} km',
                  Icons.straighten,
                  Theme.of(context).colorScheme.primary,
                ),
                _buildMetricTile(
                  context,
                  'Velocidad Media',
                  '${session.averageSpeedKmh.toStringAsFixed(1)} km/h',
                  Icons.speed,
                  Theme.of(context).colorScheme.secondary,
                ),
                _buildMetricTile(
                  context,
                  'Velocidad Máxima',
                  '${session.maxSpeedKmh.toStringAsFixed(1)} km/h',
                  Icons.flash_on,
                  Theme.of(context).colorScheme.error,
                ),
                _buildMetricTile(
                  context,
                  'Calorías',
                  '${session.caloriesBurned.toStringAsFixed(0)} kcal',
                  Icons.local_fire_department,
                  Theme.of(context).colorScheme.tertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(BuildContext context, String title, String value, IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
  final onSurface60 = scheme.onSurface.withAlpha((0.6 * 255).round());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha((0.3 * 255).round())),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: onSurface60,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMap(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Calcular el centro del mapa
    final bounds = _calculateBounds(session.routePoints);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ruta Recorrida',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: bounds['center'] as LatLng,
                  initialZoom: _calculateZoom(bounds),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.cicle_app',
                  ),
                  PolylineLayer(
                    polylines: [
                          Polyline(
                            points: session.routePoints,
                            strokeWidth: 4.0,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // Marcador de inicio
                      if (session.routePoints.isNotEmpty)
                        Marker(
                          point: session.routePoints.first,
                          width: 30,
                          height: 30,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 16,
                            ),
                          ),
                        ),
                      // Marcador de final
                      if (session.routePoints.length > 1)
                        Marker(
                          point: session.routePoints.last,
                          width: 30,
                          height: 30,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.flag,
                              color: Theme.of(context).colorScheme.onError,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Puntos de GPS registrados: ${session.routePoints.length}',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withAlpha((0.6 * 255).round()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return {
        'center': const LatLng(0, 0),
        'bounds': null,
      };
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return {
      'center': LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
      'bounds': {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
      },
    };
  }

  double _calculateZoom(Map<String, dynamic> bounds) {
    if (bounds['bounds'] == null) return 16.0;
    
    final b = bounds['bounds'] as Map<String, dynamic>;
    final latDiff = (b['maxLat'] - b['minLat']).abs();
    final lngDiff = (b['maxLng'] - b['minLng']).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    if (maxDiff > 0.1) return 10.0;
    if (maxDiff > 0.05) return 12.0;
    if (maxDiff > 0.01) return 14.0;
    if (maxDiff > 0.005) return 16.0;
    return 18.0;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}