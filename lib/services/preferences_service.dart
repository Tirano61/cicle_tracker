import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';
import '../models/map_tile_provider.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _userSettingsKey = 'user_settings';

  // Cargar configuración del usuario
  Future<UserSettings> loadUserSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_userSettingsKey);
      
      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        return UserSettings.fromMap(settingsMap);
      }
    } catch (e) {
      // Si hay error, retornar configuración por defecto
    }
    
    return UserSettings(); // Configuración por defecto
  }

  // Guardar configuración del usuario
  Future<bool> saveUserSettings(UserSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(settings.toMap());
      return await prefs.setString(_userSettingsKey, settingsJson);
    } catch (e) {
      return false;
    }
  }

  // Métodos específicos para configuraciones individuales
  Future<bool> updateWeight(double weightKg) async {
    final settings = await loadUserSettings();
    final updatedSettings = settings.copyWith(weightKg: weightKg);
    return await saveUserSettings(updatedSettings);
  }

  Future<bool> updateDistanceUnit(String unit) async {
    final settings = await loadUserSettings();
    final updatedSettings = settings.copyWith(distanceUnit: unit);
    return await saveUserSettings(updatedSettings);
  }

  Future<bool> updateSpeedUnit(String unit) async {
    final settings = await loadUserSettings();
    final updatedSettings = settings.copyWith(speedUnit: unit);
    return await saveUserSettings(updatedSettings);
  }

  Future<bool> updateVoiceAlerts(bool enabled) async {
    final settings = await loadUserSettings();
    final updatedSettings = settings.copyWith(enableVoiceAlerts: enabled);
    return await saveUserSettings(updatedSettings);
  }

  Future<bool> updateGpsInterval(int intervalSeconds) async {
    final settings = await loadUserSettings();
    final updatedSettings = settings.copyWith(gpsUpdateInterval: intervalSeconds);
    return await saveUserSettings(updatedSettings);
  }

  // Métodos para tipo de mapa
  static const String _mapProviderKey = 'selected_map_provider';

  Future<MapTileProvider> getMapProvider() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final providerName = prefs.getString(_mapProviderKey);
      
      if (providerName != null) {
        return MapTileProvider.values.firstWhere(
          (provider) => provider.name == providerName,
          orElse: () => MapTileProvider.openStreetMap,
        );
      }
    } catch (e) {
      // Si hay error, retornar por defecto
    }
    
    return MapTileProvider.openStreetMap;
  }

  Future<bool> saveMapProvider(MapTileProvider provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_mapProviderKey, provider.name);
    } catch (e) {
      return false;
    }
  }
}