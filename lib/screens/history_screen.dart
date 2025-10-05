import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/cycling_session.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<CyclingSession> _sessions = [];
  bool _isLoading = true;
  Map<String, double> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _loadStats();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    
    try {
      final sessions = await _databaseService.getAllCompletedSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error al cargar el historial');
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _databaseService.getOverallStats();
      setState(() => _stats = stats);
    } catch (e) {
      // Error silencioso para stats
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('📈 Historial'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadSessions();
              _loadStats();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel de estadísticas
          if (_stats.isNotEmpty) _buildStatsPanel(),
          
          // Lista de sesiones
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                    ? _buildEmptyState()
                    : _buildSessionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
  color: Theme.of(context).colorScheme.primary.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(12),
  border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha((0.16 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Estadísticas Generales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Sesiones',
                  '${_stats['totalSessions']?.toInt() ?? 0}',
                  Icons.directions_bike,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Distancia Total',
                  '${(_stats['totalDistance'] ?? 0).toStringAsFixed(1)} km',
                  Icons.straighten,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Velocidad Media',
                  '${(_stats['avgSpeed'] ?? 0).toStringAsFixed(1)} km/h',
                  Icons.speed,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Calorías Totales',
                  '${(_stats['totalCalories'] ?? 0).toStringAsFixed(0)} kcal',
                  Icons.local_fire_department,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha((0.7 * 255).round()),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_bike,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withAlpha((0.24 * 255).round()),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay sesiones guardadas',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha((0.7 * 255).round()),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comienza tu primera sesión de ciclismo',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha((0.6 * 255).round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(CyclingSession session) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.directions_bike,
            color: Colors.blue,
          ),
        ),
        title: Text(
          '${dateFormat.format(session.startTime)} - ${timeFormat.format(session.startTime)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${session.distanceKm.toStringAsFixed(2)} km'),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(_formatDuration(session.duration)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.speed, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${session.averageSpeedKmh.toStringAsFixed(1)} km/h'),
                const SizedBox(width: 16),
                Icon(Icons.local_fire_department, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${session.caloriesBurned.toStringAsFixed(0)} kcal'),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionDetailScreen(session: session),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}