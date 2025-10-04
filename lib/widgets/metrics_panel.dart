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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila principal de métricas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetricCard(
                title: 'Velocidad',
                value: trackingData.currentSpeedKmh.toStringAsFixed(1),
                unit: _getSpeedUnit(),
                color: Colors.blue,
                icon: Icons.speed,
              ),
              _buildMetricCard(
                title: 'Distancia',
                value: _formatDistance(trackingData.distanceKm),
                unit: _getDistanceUnit(),
                color: Colors.green,
                icon: Icons.straighten,
              ),
              _buildMetricCard(
                title: 'Tiempo',
                value: _formatDuration(trackingData.elapsedTime),
                unit: '',
                color: Colors.orange,
                icon: Icons.access_time,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Fila secundaria de métricas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetricCard(
                title: 'Velocidad Media',
                value: trackingData.averageSpeedKmh.toStringAsFixed(1),
                unit: _getSpeedUnit(),
                color: Colors.purple,
                icon: Icons.trending_up,
                isSmall: true,
              ),
              _buildMetricCard(
                title: 'Vel. Máxima',
                value: trackingData.maxSpeedKmh.toStringAsFixed(1),
                unit: _getSpeedUnit(),
                color: Colors.red,
                icon: Icons.flash_on,
                isSmall: true,
              ),
              _buildMetricCard(
                title: 'Calorías',
                value: trackingData.caloriesBurned.toStringAsFixed(0),
                unit: 'kcal',
                color: Colors.pink,
                icon: Icons.local_fire_department,
                isSmall: true,
              ),
            ],
          ),
          
          // Estado del tracking
          if (trackingData.isTracking)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: trackingData.isPaused ? Colors.orange : Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    trackingData.isPaused ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trackingData.isPaused ? 'PAUSADO' : 'GRABANDO',
                    style: const TextStyle(
                      color: Colors.white,
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required Color color,
    required IconData icon,
    bool isSmall = false,
  }) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: isSmall ? 2 : 4),
        padding: EdgeInsets.all(isSmall ? 8 : 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: isSmall ? 20 : 24,
            ),
            SizedBox(height: isSmall ? 4 : 8),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmall ? 10 : 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmall ? 2 : 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: isSmall ? 16 : 20,
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
                      fontSize: isSmall ? 10 : 12,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
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