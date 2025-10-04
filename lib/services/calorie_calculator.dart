import 'dart:math' as math;

class CalorieCalculator {
  static final CalorieCalculator _instance = CalorieCalculator._internal();
  factory CalorieCalculator() => _instance;
  CalorieCalculator._internal();

  // Constantes para cálculo de calorías
  static const double _airResistanceCoefficient = 0.5;
  static const double _rollingResistanceCoefficient = 0.004;
  static const double _bikeMassKg = 15.0; // Peso promedio de bicicleta
  static const double _gravityMs2 = 9.81;

  /// Calcular calorías quemadas basado en múltiples factores
  /// 
  /// [weightKg] - Peso del usuario en kilogramos
  /// [speedKmh] - Velocidad en km/h
  /// [timeHours] - Tiempo en horas
  /// [terrainFactor] - Factor del terreno (1.0 = plano, 1.2 = colinas ligeras, 1.5 = montañoso)
  /// [windResistance] - Resistencia del viento (0.8 = a favor, 1.0 = sin viento, 1.3 = en contra)
  double calculateCaloriesAdvanced({
    required double weightKg,
    required double speedKmh,
    required double timeHours,
    double terrainFactor = 1.0,
    double windResistance = 1.0,
  }) {
    if (speedKmh <= 0 || timeHours <= 0 || weightKg <= 0) return 0.0;

    // Convertir velocidad a m/s
    final speedMs = speedKmh / 3.6;

    // Calcular MET basado en velocidad (más preciso)
    final met = _calculateMETFromSpeed(speedKmh);

    // Fórmula básica de calorías: MET × peso × tiempo
    double baseCalories = met * weightKg * timeHours;

    // Ajustar por resistencia del aire (aumenta exponencialmente con velocidad)
    final airResistanceFactor = 1.0 + (_airResistanceCoefficient * math.pow(speedMs, 2) / 100);

    // Ajustar por resistencia de rodadura
    final rollingResistanceFactor = 1.0 + (_rollingResistanceCoefficient * speedMs);

    // Aplicar todos los factores
    double adjustedCalories = baseCalories * 
        airResistanceFactor * 
        rollingResistanceFactor * 
        terrainFactor * 
        windResistance;

    return adjustedCalories.clamp(0.0, double.infinity);
  }

  /// Calcular calorías básicas (método simplificado)
  double calculateCaloriesBasic({
    required double weightKg,
    required double averageSpeedKmh,
    required Duration duration,
  }) {
    final timeHours = duration.inMinutes / 60.0;
    
    return calculateCaloriesAdvanced(
      weightKg: weightKg,
      speedKmh: averageSpeedKmh,
      timeHours: timeHours,
    );
  }

  /// Calcular calorías en tiempo real (por minuto)
  double calculateCaloriesPerMinute({
    required double weightKg,
    required double currentSpeedKmh,
    double terrainFactor = 1.0,
    double windResistance = 1.0,
  }) {
    final caloriesPerHour = calculateCaloriesAdvanced(
      weightKg: weightKg,
      speedKmh: currentSpeedKmh,
      timeHours: 1.0,
      terrainFactor: terrainFactor,
      windResistance: windResistance,
    );

    return caloriesPerHour / 60.0; // Calorías por minuto
  }

  /// Calcular MET basado en velocidad de ciclismo
  double _calculateMETFromSpeed(double speedKmh) {
    // Valores MET más precisos basados en investigación científica
    if (speedKmh < 16.0) {
      return 4.0; // Ciclismo muy lento
    } else if (speedKmh < 19.0) {
      return 6.0; // Ciclismo lento/recreativo
    } else if (speedKmh < 22.0) {
      return 8.0; // Ciclismo moderado
    } else if (speedKmh < 25.0) {
      return 10.0; // Ciclismo vigoroso
    } else if (speedKmh < 28.0) {
      return 12.0; // Ciclismo rápido
    } else if (speedKmh < 32.0) {
      return 14.0; // Ciclismo muy rápido
    } else {
      return 16.0; // Ciclismo extremadamente rápido
    }
  }

  /// Estimar calorías por kilómetro basado en peso
  double getCaloriesPerKm(double weightKg) {
    // Fórmula aproximada: ~0.5 calorías por kg por km para ciclismo moderado
    return weightKg * 0.5;
  }

  /// Calcular gasto energético total incluyendo metabolismo basal
  double calculateTotalEnergyExpenditure({
    required double weightKg,
    required double averageSpeedKmh,
    required Duration duration,
    required int age,
    required String gender, // 'male' o 'female'
  }) {
    final timeHours = duration.inMinutes / 60.0;

    // Calcular calorías de ejercicio
    final exerciseCalories = calculateCaloriesBasic(
      weightKg: weightKg,
      averageSpeedKmh: averageSpeedKmh,
      duration: duration,
    );

    // Calcular metabolismo basal por hora (fórmula Harris-Benedict simplificada)
    double bmrPerHour;
    if (gender.toLowerCase() == 'male') {
      bmrPerHour = (88.362 + (13.397 * weightKg) + (4.799 * 175) - (5.677 * age)) / 24;
    } else {
      bmrPerHour = (447.593 + (9.247 * weightKg) + (3.098 * 165) - (4.330 * age)) / 24;
    }

    final basalCalories = bmrPerHour * timeHours;

    return exerciseCalories + basalCalories;
  }

  /// Calcular potencia estimada en vatios
  double calculateEstimatedPower({
    required double weightKg,
    required double speedKmh,
    double terrainGrade = 0.0, // Pendiente en porcentaje
    double windSpeedKmh = 0.0,
    double cyclingEfficiency = 0.22, // Eficiencia mecánica (~22% típico)
  }) {
    final speedMs = speedKmh / 3.6;
    final totalMassKg = weightKg + _bikeMassKg;

    // Potencia por resistencia de rodadura
    final rollingPower = _rollingResistanceCoefficient * totalMassKg * _gravityMs2 * speedMs;

    // Potencia por resistencia del aire
    final airDensity = 1.225; // kg/m³ al nivel del mar
    final frontalArea = 0.4; // m² área frontal típica del ciclista
    final dragCoefficient = 0.9; // Coeficiente de arrastre típico
    final windSpeedMs = windSpeedKmh / 3.6;
    final relativeWindSpeed = speedMs + windSpeedMs;
    
    final aeroPower = 0.5 * airDensity * frontalArea * dragCoefficient * 
                     math.pow(relativeWindSpeed, 3);

    // Potencia por gravedad (subidas)
    final gradePower = totalMassKg * _gravityMs2 * (terrainGrade / 100) * speedMs;

    // Potencia total mecánica
    final mechanicalPower = rollingPower + aeroPower + gradePower;

    // Potencia metabólica (considerando eficiencia)
    final metabolicPower = mechanicalPower / cyclingEfficiency;

    return metabolicPower.clamp(0.0, 2000.0); // Limitar a valores razonables
  }

  /// Obtener zona de entrenamiento basada en calorías por minuto
  String getTrainingZone(double caloriesPerMinute, double weightKg) {
    final caloriesPerKg = caloriesPerMinute / weightKg;
    
    if (caloriesPerKg < 0.1) {
      return 'Recuperación';
    } else if (caloriesPerKg < 0.15) {
      return 'Zona 1 - Aeróbica Base';
    } else if (caloriesPerKg < 0.2) {
      return 'Zona 2 - Aeróbica';
    } else if (caloriesPerKg < 0.25) {
      return 'Zona 3 - Tempo';
    } else if (caloriesPerKg < 0.3) {
      return 'Zona 4 - Umbral';
    } else {
      return 'Zona 5 - VO2 Max';
    }
  }
}