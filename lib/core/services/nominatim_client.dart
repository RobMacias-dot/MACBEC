import 'dart:convert';

import 'package:http/http.dart' as http;

class NominatimSuggestion {
  const NominatimSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;
}

/// Cliente HTTP directo para el servicio público de búsqueda de
/// OpenStreetMap (Nominatim). No requiere API key, pero su política de uso
/// pide un User-Agent identificable y un máximo razonable de ~1 solicitud
/// por segundo: https://operations.osmfoundation.org/policies/nominatim/
class NominatimClient {
  NominatimClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';
  static const _userAgent = 'MacBecSolarApp/1.0 (contacto@macbecsolar.com)';

  final http.Client _httpClient;

  Future<List<NominatimSuggestion>> search(
    String query, {
    int limit = 5,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 3) return const [];

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'q': trimmedQuery,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '$limit',
        'countrycodes': 'mx',
      },
    );

    final response = await _httpClient.get(
      uri,
      headers: const {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      throw StateError(
        'No se pudo consultar Nominatim (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;

    return decoded
        .map((item) {
          final map = item as Map<String, dynamic>;
          final lat = double.tryParse('${map['lat']}');
          final lon = double.tryParse('${map['lon']}');
          final displayName = map['display_name'] as String?;

          if (lat == null || lon == null || displayName == null) return null;

          return NominatimSuggestion(
            displayName: displayName,
            latitude: lat,
            longitude: lon,
          );
        })
        .whereType<NominatimSuggestion>()
        .toList();
  }
}
