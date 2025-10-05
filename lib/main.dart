import 'package:flutter/material.dart';
import 'screens/tracking_screen.dart';
import 'widgets/splash_screen.dart';

void main() {
  runApp(const CycleApp());
}

class CycleApp extends StatefulWidget {
  const CycleApp({super.key});

  @override
  State<CycleApp> createState() => _CycleAppState();
}

class _CycleAppState extends State<CycleApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
