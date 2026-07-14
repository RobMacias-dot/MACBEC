class MexicoStateLocation {
  const MexicoStateLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

/// Coordenadas aproximadas del centroide de cada entidad federativa, solo
/// para consultar el promedio de radiación solar por estado en la API de
/// NASA POWER. No son coordenadas exactas del sitio de instalación.
class MexicoStates {
  const MexicoStates._();

  static const values = <MexicoStateLocation>[
    MexicoStateLocation(name: 'Aguascalientes', latitude: 21.8853, longitude: -102.2916),
    MexicoStateLocation(name: 'Baja California', latitude: 30.8406, longitude: -115.2838),
    MexicoStateLocation(name: 'Baja California Sur', latitude: 26.0444, longitude: -111.6661),
    MexicoStateLocation(name: 'Campeche', latitude: 19.8301, longitude: -90.5349),
    MexicoStateLocation(name: 'Chiapas', latitude: 16.7569, longitude: -93.1292),
    MexicoStateLocation(name: 'Chihuahua', latitude: 28.6329, longitude: -106.0691),
    MexicoStateLocation(name: 'Ciudad de México', latitude: 19.4326, longitude: -99.1332),
    MexicoStateLocation(name: 'Coahuila', latitude: 27.0587, longitude: -101.7068),
    MexicoStateLocation(name: 'Colima', latitude: 19.2452, longitude: -103.7241),
    MexicoStateLocation(name: 'Durango', latitude: 24.5593, longitude: -104.6588),
    MexicoStateLocation(name: 'Estado de México', latitude: 19.3587, longitude: -99.8874),
    MexicoStateLocation(name: 'Guanajuato', latitude: 21.0190, longitude: -101.2574),
    MexicoStateLocation(name: 'Guerrero', latitude: 17.4392, longitude: -99.5451),
    MexicoStateLocation(name: 'Hidalgo', latitude: 20.0911, longitude: -98.7624),
    MexicoStateLocation(name: 'Jalisco', latitude: 20.6595, longitude: -103.3494),
    MexicoStateLocation(name: 'Michoacán', latitude: 19.5665, longitude: -101.7068),
    MexicoStateLocation(name: 'Morelos', latitude: 18.6813, longitude: -99.1013),
    MexicoStateLocation(name: 'Nayarit', latitude: 21.7514, longitude: -104.8455),
    MexicoStateLocation(name: 'Nuevo León', latitude: 25.5922, longitude: -99.9962),
    MexicoStateLocation(name: 'Oaxaca', latitude: 17.0732, longitude: -96.7266),
    MexicoStateLocation(name: 'Puebla', latitude: 19.0414, longitude: -98.2063),
    MexicoStateLocation(name: 'Querétaro', latitude: 20.5888, longitude: -100.3899),
    MexicoStateLocation(name: 'Quintana Roo', latitude: 19.1817, longitude: -88.4791),
    MexicoStateLocation(name: 'San Luis Potosí', latitude: 22.1565, longitude: -100.9855),
    MexicoStateLocation(name: 'Sinaloa', latitude: 25.1721, longitude: -107.4795),
    MexicoStateLocation(name: 'Sonora', latitude: 29.2972, longitude: -110.3309),
    MexicoStateLocation(name: 'Tabasco', latitude: 17.8409, longitude: -92.6189),
    MexicoStateLocation(name: 'Tamaulipas', latitude: 24.2669, longitude: -98.8363),
    MexicoStateLocation(name: 'Tlaxcala', latitude: 19.3139, longitude: -98.2404),
    MexicoStateLocation(name: 'Veracruz', latitude: 19.1738, longitude: -96.1342),
    MexicoStateLocation(name: 'Yucatán', latitude: 20.7099, longitude: -89.0943),
    MexicoStateLocation(name: 'Zacatecas', latitude: 22.7709, longitude: -102.5832),
  ];

  static MexicoStateLocation? findByName(String name) {
    for (final state in values) {
      if (state.name == name) return state;
    }
    return null;
  }
}
