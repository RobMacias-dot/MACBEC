import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macbec_solar_app/app/app.dart';

void main() {
  testWidgets('MacBec Solar muestra pantalla inicial', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MacBecSolarApp(),
      ),
    );

    expect(find.text('MacBec Solar'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
