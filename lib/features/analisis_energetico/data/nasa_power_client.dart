import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final nasaPowerClientProvider = Provider<NasaPowerClient>(
  (ref) => NasaPowerClient(),
);

/// Cliente de solo lectura para la API pública de NASA POWER
/// (climatología de radiación solar). Nunca lanza excepciones hacia el
/// llamador: si no hay conexión o la respuesta no es la esperada, regresa
/// null para que la app siga funcionando offline con datos guardados o
/// captura manual.
class NasaPowerClient {
  static const _baseUrl =
      'https://power.larc.nasa.gov/api/temporal/climatology/point';

  /// Promedio anual de horas solares pico (kWh/m²/día equivale
  /// numéricamente a horas solares pico) para una ubicación.
  Future<double?> fetchAnnualPeakSunHours({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'parameters': 'ALLSKY_SFC_SW_DWN',
        'community': 'RE',
        'longitude': longitude.toString(),
        'latitude': latitude.toString(),
        'format': 'JSON',
      },
    );

    try {
      final response = await http.get(uri).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final properties = body['properties'] as Map<String, dynamic>?;
      final parameter = properties?['parameter'] as Map<String, dynamic>?;
      final irradiance =
          parameter?['ALLSKY_SFC_SW_DWN'] as Map<String, dynamic>?;
      final annual = irradiance?['ANN'];

      if (annual is num && annual > 0) {
        return annual.toDouble();
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
