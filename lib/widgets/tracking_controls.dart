import 'package:flutter/material.dart';

class TrackingControls extends StatelessWidget {
  final bool isTracking;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const TrackingControls({
    super.key,
    required this.isTracking,
    required this.isPaused,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha((0.08 * 255).round()),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (!isTracking) 
              _buildCompactButton(
                onPressed: onStart,
                icon: Icons.play_arrow,
                label: 'Iniciar',
                color: Theme.of(context).colorScheme.primary,
              )
            else ...[
              // Botón de pausa/reanudar
              _buildCompactButton(
                onPressed: isPaused ? onResume : onPause,
                icon: isPaused ? Icons.play_arrow : Icons.pause,
                label: isPaused ? 'Reanudar' : 'Pausar',
                color: isPaused ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
              ),
              
              // Botón de parar
              _buildCompactButton(
                onPressed: () => _showStopConfirmation(context),
                icon: Icons.stop,
                label: 'Finalizar',
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: color,
        size: 18,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  backgroundColor: color.withAlpha((0.08 * 255).round()),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withAlpha((0.25 * 255).round())),
        ),
      ),
    );
  }

  void _showStopConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Finalizar Sesión'),
          content: const Text('¿Estás seguro de que quieres finalizar esta sesión? Los datos se guardarán automáticamente.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onStop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Finalizar'),
            ),
          ],
        );
      },
    );
  }
}