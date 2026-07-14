import 'package:flutter_test/flutter_test.dart';
import 'package:macbec_solar_app/features/analisis_energetico/domain/mexico_states.dart';

void main() {
  test('incluye las 32 entidades federativas sin nombres repetidos', () {
    final names = MexicoStates.values.map((state) => state.name).toSet();

    expect(MexicoStates.values.length, equals(32));
    expect(names.length, equals(32));
  });

  test('todas las coordenadas caen dentro del territorio mexicano aproximado',
      () {
    for (final state in MexicoStates.values) {
      expect(
        state.latitude,
        inInclusiveRange(14.0, 33.0),
        reason: '${state.name} tiene una latitud fuera de rango',
      );
      expect(
        state.longitude,
        inInclusiveRange(-118.0, -86.0),
        reason: '${state.name} tiene una longitud fuera de rango',
      );
    }
  });

  test('findByName encuentra un estado existente e ignora uno inexistente',
      () {
    expect(MexicoStates.findByName('Jalisco')?.name, equals('Jalisco'));
    expect(MexicoStates.findByName('Narnia'), isNull);
  });
}
