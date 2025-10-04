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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
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
              _buildControlButton(
                onPressed: onStart,
                icon: Icons.play_arrow,
                label: 'Iniciar',
                color: Colors.green,
                size: 60,
              )
            else ...[
              // Botón de pausa/reanudar
              _buildControlButton(
                onPressed: isPaused ? onResume : onPause,
                icon: isPaused ? Icons.play_arrow : Icons.pause,
                label: isPaused ? 'Reanudar' : 'Pausar',
                color: isPaused ? Colors.green : Colors.orange,
                size: 50,
              ),
              
              // Botón de parar
              _buildControlButton(
                onPressed: () => _showStopConfirmation(context),
                icon: Icons.stop,
                label: 'Finalizar',
                color: Colors.red,
                size: 50,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required double size,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: size * 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Finalizar'),
            ),
          ],
        );
      },
    );
  }
}