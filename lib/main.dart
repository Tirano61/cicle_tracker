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
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
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
