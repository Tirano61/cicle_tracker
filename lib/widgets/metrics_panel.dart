import 'package:flutter/material.dart';
import '../models/live_tracking_data.dart';
import '../models/user_settings.dart';

class MetricsPanel extends StatelessWidget {
  final LiveTrackingData trackingData;
  final UserSettings userSettings;

  const MetricsPanel({
    super.key,
    required this.trackingData,
    required this.userSettings,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha((0.3 * 255).round()),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Velocidad actual prominente
          _buildSpeedCard(
            context,
            value: trackingData.currentSpeedKmh.toStringAsFixed(1),
            unit: _getSpeedUnit(),
          ),
          
          const SizedBox(height: 12),
          
          // Fila principal de métricas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCompactMetricCard(
                context,
                title: 'Distancia',
                value: _formatDistance(trackingData.distanceKm),
                unit: _getDistanceUnit(),
            color: Theme.of(context).colorScheme.onSurface,
                icon: Icons.straighten,
              ),
              _buildCompactMetricCard(
                context,
                title: 'Tiempo',
                value: _formatDuration(trackingData.elapsedTime),
                unit: '',
                color: Theme.of(context).colorScheme.onSurface,
                icon: Icons.access_time,
              ),
              _buildCompactMetricCard(
                context,
                title: 'Calorías',
                value: trackingData.caloriesBurned.toStringAsFixed(0),
                unit: 'kcal',
                color: Theme.of(context).colorScheme.onSurface,
                icon: Icons.local_fire_department,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Fila secundaria de métricas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCompactMetricCard(
                context,
                title: 'Velocidad Media',
                value: trackingData.averageSpeedKmh.toStringAsFixed(1),
                unit: _getSpeedUnit(),
                color: Theme.of(context).colorScheme.onSurface.withAlpha((0.8 * 255).round()),
                icon: Icons.trending_up,
                isSmaller: true,
              ),
              _buildCompactMetricCard(
                context,
                title: 'Vel. Máxima',
                value: trackingData.maxSpeedKmh.toStringAsFixed(1),
                unit: _getSpeedUnit(),
                color: Theme.of(context).colorScheme.onSurface.withAlpha((0.8 * 255).round()),
                icon: Icons.flash_on,
                isSmaller: true,
              ),
            ],
          ),
          
          // Estado del tracking
          if (trackingData.isTracking)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: trackingData.isPaused ? Theme.of(context).colorScheme.secondary : Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    trackingData.isPaused ? Icons.pause : Icons.play_arrow,
                    color: scheme.onPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trackingData.isPaused ? 'PAUSADO' : 'GRABANDO',
                    style: TextStyle(
                      color: trackingData.isPaused ? scheme.onPrimary : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Tarjeta de velocidad prominente
  Widget _buildSpeedCard(BuildContext context, {
    required String value,
    required String unit,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.speed,
            color: Colors.grey[800],
            size: 36,
          ),
          const SizedBox(width: 20),
          Text(
            value,
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              unit,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tarjetas compactas con icono a la izquierda
  Widget _buildCompactMetricCard(BuildContext context, {
    required String title,
    required String value,
    required String unit,
    required Color color,
    required IconData icon,
    bool isSmaller = false,
  }) {
    // accept context usage via Theme.of wherever needed by caller
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.all(isSmaller ? 5 : 8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: isSmaller ? 18 : 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmaller ? 10 : 12,
                      fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: isSmaller ? 16 : 20,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unit.isNotEmpty) ...[
                        const SizedBox(width: 2),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: isSmaller ? 9 : 10,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha((0.8 * 255).round()),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double km) {
    if (userSettings.distanceUnit == 'miles') {
      final miles = km * 0.621371;
      return miles.toStringAsFixed(2);
    }
    return km.toStringAsFixed(2);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(1, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _getSpeedUnit() {
    return userSettings.speedUnit == 'mph' ? 'mph' : 'km/h';
  }

  String _getDistanceUnit() {
    return userSettings.distanceUnit == 'miles' ? 'mi' : 'km';
  }
}