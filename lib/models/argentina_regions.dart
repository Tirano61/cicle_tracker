class ArgentinaProvince {
  final String name;
  final String code;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  final int estimatedTileCount;
  final double estimatedSizeMB;

  const ArgentinaProvince({
    required this.name,
    required this.code,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.estimatedTileCount,
    required this.estimatedSizeMB,
  });

  // Calcular área aproximada en km²
  double get areaKm2 {
    const double kmPerDegreeLat = 111.0;
    final double kmPerDegreeLng = 111.0 * (maxLat + minLat) / 2 * 0.017453; // cos(avg lat in radians)
    final double widthKm = (maxLng - minLng) * kmPerDegreeLng;
    final double heightKm = (maxLat - minLat) * kmPerDegreeLat;
    return widthKm * heightKm;
  }
}

class ArgentinaRegions {
  static const List<ArgentinaProvince> provinces = [
    // Región Noroeste (NOA)
    ArgentinaProvince(
      name: 'Jujuy',
      code: 'JY',
      minLat: -24.6,
      maxLat: -21.8,
      minLng: -67.0,
      maxLng: -64.0,
      estimatedTileCount: 15000,
      estimatedSizeMB: 45.0,
    ),
    ArgentinaProvince(
      name: 'Salta',
      code: 'SA',
      minLat: -25.8,
      maxLat: -21.8,
      minLng: -67.8,
      maxLng: -62.3,
      estimatedTileCount: 28000,
      estimatedSizeMB: 84.0,
    ),
    ArgentinaProvince(
      name: 'Tucumán',
      code: 'TM',
      minLat: -27.6,
      maxLat: -26.0,
      minLng: -66.0,
      maxLng: -64.4,
      estimatedTileCount: 12000,
      estimatedSizeMB: 36.0,
    ),
    ArgentinaProvince(
      name: 'Catamarca',
      code: 'CT',
      minLat: -28.8,
      maxLat: -25.2,
      minLng: -69.0,
      maxLng: -64.8,
      estimatedTileCount: 22000,
      estimatedSizeMB: 66.0,
    ),
    ArgentinaProvince(
      name: 'Santiago del Estero',
      code: 'SE',
      minLat: -29.5,
      maxLat: -25.2,
      minLng: -65.5,
      maxLng: -61.7,
      estimatedTileCount: 20000,
      estimatedSizeMB: 60.0,
    ),
    ArgentinaProvince(
      name: 'La Rioja',
      code: 'LR',
      minLat: -30.4,
      maxLat: -28.0,
      minLng: -69.5,
      maxLng: -66.0,
      estimatedTileCount: 18000,
      estimatedSizeMB: 54.0,
    ),

    // Región Noreste (NEA)
    ArgentinaProvince(
      name: 'Formosa',
      code: 'FM',
      minLat: -26.2,
      maxLat: -22.0,
      minLng: -62.4,
      maxLng: -57.6,
      estimatedTileCount: 25000,
      estimatedSizeMB: 75.0,
    ),
    ArgentinaProvince(
      name: 'Chaco',
      code: 'CC',
      minLat: -27.6,
      maxLat: -24.1,
      minLng: -62.4,
      maxLng: -58.9,
      estimatedTileCount: 20000,
      estimatedSizeMB: 60.0,
    ),
    ArgentinaProvince(
      name: 'Corrientes',
      code: 'CN',
      minLat: -30.8,
      maxLat: -27.0,
      minLng: -59.8,
      maxLng: -55.7,
      estimatedTileCount: 22000,
      estimatedSizeMB: 66.0,
    ),
    ArgentinaProvince(
      name: 'Misiones',
      code: 'MN',
      minLat: -28.2,
      maxLat: -25.2,
      minLng: -56.5,
      maxLng: -53.6,
      estimatedTileCount: 15000,
      estimatedSizeMB: 45.0,
    ),

    // Región Centro
    ArgentinaProvince(
      name: 'Santa Fe',
      code: 'SF',
      minLat: -34.0,
      maxLat: -28.0,
      minLng: -62.9,
      maxLng: -58.8,
      estimatedTileCount: 35000,
      estimatedSizeMB: 105.0,
    ),
    ArgentinaProvince(
      name: 'Entre Ríos',
      code: 'ER',
      minLat: -34.0,
      maxLat: -30.1,
      minLng: -60.8,
      maxLng: -57.8,
      estimatedTileCount: 18000,
      estimatedSizeMB: 54.0,
    ),
    ArgentinaProvince(
      name: 'Córdoba',
      code: 'CB',
      minLat: -35.0,
      maxLat: -29.5,
      minLng: -65.6,
      maxLng: -61.7,
      estimatedTileCount: 30000,
      estimatedSizeMB: 90.0,
    ),

    // Región Cuyo
    ArgentinaProvince(
      name: 'San Luis',
      code: 'SL',
      minLat: -34.3,
      maxLat: -32.0,
      minLng: -67.5,
      maxLng: -64.9,
      estimatedTileCount: 15000,
      estimatedSizeMB: 45.0,
    ),
    ArgentinaProvince(
      name: 'San Juan',
      code: 'SJ',
      minLat: -32.5,
      maxLat: -28.8,
      minLng: -70.1,
      maxLng: -66.9,
      estimatedTileCount: 20000,
      estimatedSizeMB: 60.0,
    ),
    ArgentinaProvince(
      name: 'Mendoza',
      code: 'MZ',
      minLat: -37.6,
      maxLat: -32.0,
      minLng: -70.6,
      maxLng: -66.9,
      estimatedTileCount: 40000,
      estimatedSizeMB: 120.0,
    ),

    // Región Pampeana
    ArgentinaProvince(
      name: 'Buenos Aires',
      code: 'BA',
      minLat: -41.0,
      maxLat: -33.3,
      minLng: -63.4,
      maxLng: -56.7,
      estimatedTileCount: 80000,
      estimatedSizeMB: 240.0,
    ),
    ArgentinaProvince(
      name: 'Ciudad Autónoma de Buenos Aires',
      code: 'CABA',
      minLat: -34.7,
      maxLat: -34.5,
      minLng: -58.5,
      maxLng: -58.3,
      estimatedTileCount: 2000,
      estimatedSizeMB: 6.0,
    ),
    ArgentinaProvince(
      name: 'La Pampa',
      code: 'LP',
      minLat: -39.7,
      maxLat: -35.0,
      minLng: -67.5,
      maxLng: -63.0,
      estimatedTileCount: 25000,
      estimatedSizeMB: 75.0,
    ),

    // Región Patagonia
    ArgentinaProvince(
      name: 'Neuquén',
      code: 'NQ',
      minLat: -41.0,
      maxLat: -36.0,
      minLng: -71.2,
      maxLng: -68.0,
      estimatedTileCount: 35000,
      estimatedSizeMB: 105.0,
    ),
    ArgentinaProvince(
      name: 'Río Negro',
      code: 'RN',
      minLat: -42.0,
      maxLat: -37.5,
      minLng: -71.9,
      maxLng: -62.8,
      estimatedTileCount: 50000,
      estimatedSizeMB: 150.0,
    ),
    ArgentinaProvince(
      name: 'Chubut',
      code: 'CH',
      minLat: -46.0,
      maxLat: -42.0,
      minLng: -71.6,
      maxLng: -63.8,
      estimatedTileCount: 45000,
      estimatedSizeMB: 135.0,
    ),
    ArgentinaProvince(
      name: 'Santa Cruz',
      code: 'SC',
      minLat: -52.4,
      maxLat: -46.0,
      minLng: -73.6,
      maxLng: -65.9,
      estimatedTileCount: 65000,
      estimatedSizeMB: 195.0,
    ),
    ArgentinaProvince(
      name: 'Tierra del Fuego',
      code: 'TF',
      minLat: -55.1,
      maxLat: -52.4,
      minLng: -68.6,
      maxLng: -63.8,
      estimatedTileCount: 18000,
      estimatedSizeMB: 54.0,
    ),
  ];

  // Calcular totales para toda Argentina
  static int get totalEstimatedTiles => 
      provinces.fold(0, (sum, province) => sum + province.estimatedTileCount);

  static double get totalEstimatedSizeMB => 
      provinces.fold(0.0, (sum, province) => sum + province.estimatedSizeMB);

  // Obtener provincia por código
  static ArgentinaProvince? getProvinceByCode(String code) {
    try {
      return provinces.firstWhere((province) => province.code == code);
    } catch (e) {
      return null;
    }
  }

  // Agrupar provincias por región
  static Map<String, List<ArgentinaProvince>> get provincesByRegion => {
    'Noroeste (NOA)': provinces.sublist(0, 6),
    'Noreste (NEA)': provinces.sublist(6, 10),
    'Centro': provinces.sublist(10, 13),
    'Cuyo': provinces.sublist(13, 16),
    'Pampeana': provinces.sublist(16, 19),
    'Patagonia': provinces.sublist(19, 24),
  };

  // Calcular bounds para múltiples provincias seleccionadas
  static Map<String, double> calculateBounds(List<ArgentinaProvince> selectedProvinces) {
    if (selectedProvinces.isEmpty) {
      return {'minLat': 0, 'maxLat': 0, 'minLng': 0, 'maxLng': 0};
    }

    double minLat = selectedProvinces.first.minLat;
    double maxLat = selectedProvinces.first.maxLat;
    double minLng = selectedProvinces.first.minLng;
    double maxLng = selectedProvinces.first.maxLng;

    for (final province in selectedProvinces) {
      if (province.minLat < minLat) minLat = province.minLat;
      if (province.maxLat > maxLat) maxLat = province.maxLat;
      if (province.minLng < minLng) minLng = province.minLng;
      if (province.maxLng > maxLng) maxLng = province.maxLng;
    }

    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    };
  }

  // Calcular totales para provincias seleccionadas
  static Map<String, dynamic> calculateTotals(List<ArgentinaProvince> selectedProvinces) {
    final totalTiles = selectedProvinces.fold(0, (sum, province) => sum + province.estimatedTileCount);
    final totalSize = selectedProvinces.fold(0.0, (sum, province) => sum + province.estimatedSizeMB);
    final totalArea = selectedProvinces.fold(0.0, (sum, province) => sum + province.areaKm2);

    return {
      'tiles': totalTiles,
      'sizeMB': totalSize,
      'areaKm2': totalArea,
    };
  }
}