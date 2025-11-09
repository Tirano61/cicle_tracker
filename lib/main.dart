import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/tracking_screen.dart';
import 'widgets/splash_screen.dart';
import 'controllers/tracking_controller.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Solo inicializar el servicio de background una vez
  try {
    await BackgroundLocationService.initializeService();
  } catch (e) {
    debugPrint('[Main] Error initializing background service: $e');
  }
  
  runApp(const CycleApp());
}

class CycleApp extends StatefulWidget {
  const CycleApp({super.key});

  @override
  State<CycleApp> createState() => _CycleAppState();
}

class _CycleAppState extends State<CycleApp> with WidgetsBindingObserver {
  bool _showSplash = true;
  late final TrackingController _trackingController;

  @override
  void initState() {
    super.initState();
    _trackingController = TrackingController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trackingController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Manejar cambios en el ciclo de vida de la app
    switch (state) {
      case AppLifecycleState.paused:
        // App va a segundo plano
        debugPrint('[CycleApp] App paused - going to background');
        break;
      case AppLifecycleState.resumed:
        // App vuelve al primer plano
        debugPrint('[CycleApp] App resumed - back to foreground');
        break;
      case AppLifecycleState.detached:
        // App se está cerrando
        debugPrint('[CycleApp] App detached - shutting down');
        break;
      case AppLifecycleState.inactive:
        // App temporalmente inactiva
        debugPrint('[CycleApp] App inactive');
        break;
      case AppLifecycleState.hidden:
        // App oculta
        debugPrint('[CycleApp] App hidden');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Provider<TrackingController>.value(
      value: _trackingController,
      child: MaterialApp(
        title: 'CycleTracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF764BA2), // violeta principal
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: ColorScheme.fromSeed(seedColor: const Color(0xFF764BA2)).primary,
            foregroundColor: ThemeData().colorScheme.onPrimary,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
              backgroundColor: ColorScheme.fromSeed(seedColor: const Color(0xFF764BA2)).primary,
              foregroundColor: ThemeData().colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF764BA2),
            foregroundColor: Colors.white,
          ),
        ),
        home: _showSplash
            ? SplashScreen(
                onSplashComplete: () {
                  setState(() {
                    _showSplash = false;
                  });
                },
              )
            : const TrackingScreen(),
      )
    );
  }
}
