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
          // Velocidad actual prominente
          _buildSpeedCard(
            value: trackingData.currentSpeedKmh.toStringAsFixed(1),
            unit: _getSpeedUnit(),
          ),
          
          const SizedBox(height: 16),
          
          // Fila principal de métricas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCompactMetricCard(
                title: 'Distancia',
                value: _formatDistance(trackingData.distanceKm),
                unit: _getDistanceUnit(),
                color: Colors.grey[800]!,
                icon: Icons.straighten,
              ),
              _buildCompactMetricCard(
                title: 'Tiempo',
                value: _formatDuration(trackingData.elapsedTime),
                unit: '',
                color: Colors.grey[800]!,
                icon: Icons.access_time,
              ),
              _buildCompactMetricCard(
                title: 'Calorías',
                value: trackingData.caloriesBurned.toStringAsFixed(0),
                unit: 'kcal',
                color: Colors.grey[800]!,
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
                title: 'Velocidad Media',
                value: trackingData.averageSpeedKmh.toStringAsFixed(1),
                unit: _getSpeedUnit(),
                color: Colors.grey[700]!,
                icon: Icons.trending_up,
                isSmaller: true,
              ),
              _buildCompactMetricCard(
                title: 'Vel. Máxima',
                value: trackingData.maxSpeedKmh.toStringAsFixed(1),
                unit: _getSpeedUnit(),
                color: Colors.grey[700]!,
                icon: Icons.flash_on,
                isSmaller: true,
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

  // Tarjeta de velocidad prominente
  Widget _buildSpeedCard({
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
              color: Colors.grey[900],
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
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tarjetas compactas con icono a la izquierda
  Widget _buildCompactMetricCard({
    required String title,
    required String value,
    required String unit,
    required Color color,
    required IconData icon,
    bool isSmaller = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.all(isSmaller ? 8 : 12),
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
                      fontSize: isSmaller ? 10 : 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
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
                            fontSize: isSmaller ? 14 : 16,
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
                            color: color.withOpacity(0.8),
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