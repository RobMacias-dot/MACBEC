import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macbec_solar_app/app/app.dart';

void main() {
  testWidgets('MacBec Solar construye la pantalla splash sin errores',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MacBecSolarApp(),
      ),
    );

    // La pantalla inicial redirige de forma asíncrona según la sesión local
    // (SQLite/Secure Storage), lo cual requiere plugins no disponibles en
    // este entorno de pruebas. Este smoke test solo valida que el árbol de
    // widgets inicial (splash) se construye sin lanzar excepciones.
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
