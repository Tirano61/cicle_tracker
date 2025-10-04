import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashComplete;

  const SplashScreen({Key? key, required this.onSplashComplete}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Controlador de rotación para la rueda
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Controlador de fade para el texto
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Animación de rotación continua
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    // Animación de fade in/out para el texto
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  void _startAnimations() async {
    // Iniciar rotación continua
    _rotationController.repeat();

    // Fade in del texto después de un momento
    await Future.delayed(const Duration(milliseconds: 500));
    _fadeController.forward();

    // Completar splash después de 3 segundos total
    await Future.delayed(const Duration(milliseconds: 2500));
    widget.onSplashComplete();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rueda de bicicleta animada
              AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: const BikeWheel(),
                  );
                },
              ),
              
              const SizedBox(height: 60),
              
              // Texto animado
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      children: [
                        Text(
                          'Cicle Tracker',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.95),
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tu compañero de ciclismo',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 80),
              
              // Indicador de carga
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value * 0.7,
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BikeWheel extends StatelessWidget {
  const BikeWheel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: BikeWheelPainter(),
      ),
    );
  }
}

class BikeWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    
    // Pincel para el aro exterior
    final rimPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
      
    // Pincel para el aro interior
    final innerRimPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
      
    // Pincel para los rayos
    final spokesPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
      
    // Pincel para el centro
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Dibujar aro exterior
    canvas.drawCircle(center, radius, rimPaint);
    
    // Dibujar aro interior
    canvas.drawCircle(center, radius * 0.75, innerRimPaint);
    
    // Dibujar rayos (8 rayos)
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      final startPoint = Offset(
        center.dx + math.cos(angle) * (radius * 0.75),
        center.dy + math.sin(angle) * (radius * 0.75),
      );
      final endPoint = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      
      canvas.drawLine(startPoint, endPoint, spokesPaint);
    }
    
    // Dibujar centro de la rueda
    canvas.drawCircle(center, 8, centerPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}