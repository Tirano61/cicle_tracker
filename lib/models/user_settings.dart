class UserSettings {
  final double weightKg;
  final String distanceUnit; // 'km' o 'miles'
  final String speedUnit; // 'kmh' o 'mph'
  final bool enableVoiceAlerts;

  UserSettings({
    this.weightKg = 70.0, // Peso por defecto
    this.distanceUnit = 'km',
    this.speedUnit = 'kmh',
  this.enableVoiceAlerts = true,
  });

  // Convertir a Map para SharedPreferences
  Map<String, dynamic> toMap() {
    return {
      'weightKg': weightKg,
      'distanceUnit': distanceUnit,
      'speedUnit': speedUnit,
  'enableVoiceAlerts': enableVoiceAlerts,
    };
  }

  // Crear desde Map de SharedPreferences
  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      weightKg: map['weightKg']?.toDouble() ?? 70.0,
      distanceUnit: map['distanceUnit'] ?? 'km',
      speedUnit: map['speedUnit'] ?? 'kmh',
  enableVoiceAlerts: map['enableVoiceAlerts'] ?? true,
    );
  }

  // Crear copia con cambios
  UserSettings copyWith({
    double? weightKg,
    String? distanceUnit,
    String? speedUnit,
    bool? enableVoiceAlerts,
  // Note: gpsUpdateInterval removed — keep signature compatible by ignoring it if present
  }) {
    return UserSettings(
      weightKg: weightKg ?? this.weightKg,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      speedUnit: speedUnit ?? this.speedUnit,
  enableVoiceAlerts: enableVoiceAlerts ?? this.enableVoiceAlerts,
    );
  }

  @override
  String toString() {
    return 'UserSettings{weightKg: $weightKg, distanceUnit: $distanceUnit, speedUnit: $speedUnit}';
  }
}