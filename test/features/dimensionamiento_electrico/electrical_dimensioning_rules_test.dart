import 'package:flutter_test/flutter_test.dart';
import 'package:macbec_solar_app/features/catalogo_tecnico/domain/entities/solar_inverter.dart';
import 'package:macbec_solar_app/features/catalogo_tecnico/domain/entities/solar_panel.dart';
import 'package:macbec_solar_app/features/dimensionamiento_electrico/domain/electrical_dimensioning_rules.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  final panel = SolarPanel(
    id: 'panel-1',
    brand: 'Test',
    model: 'P400',
    powerWatts: 400,
    voc: 40,
    isc: 10,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );

  final inverter = SolarInverter(
    id: 'inverter-1',
    brand: 'Test',
    model: 'I6000',
    nominalPowerWatts: 5000,
    maxPvPowerWatts: 6000,
    maxDcVoltage: 500,
    maxShortCircuitCurrentPerMppt: 20,
    maxOutputCurrent: 25,
    mpptCount: 2,
    createdAt: now,
    updatedAt: now,
  );

  ElectricalDimensioningOption calculateOption({int requiredPanels = 20}) {
    final result = ElectricalDimensioningRules.calculate(
      ElectricalDimensioningInput(
        requiredPanels: requiredPanels,
        panelPowerWatts: panel.powerWatts,
        selectedPanel: panel,
        inverters: [inverter],
      ),
    );

    return result.options.single;
  }

  test('calcula inversores requeridos por capacidad FV maxima', () {
    final option = calculateOption();

    // 20 paneles x 400 W = 8000 W; capacidad por inversor 6000 W.
    expect(option.totalPanelPowerWatts, equals(8000));
    expect(option.requiredInverters, equals(2));
    expect(option.totalPvCapacityWatts, equals(12000));
    expect(option.inverterUsagePercent, closeTo(66.67, 0.01));
    expect(option.isPowerCompatible, isTrue);
  });

  test('valida paneles por string y paralelos por MPPT con Voc/Isc', () {
    final option = calculateOption();

    // floor(500/40) = 12 paneles por string; floor(20/10) = 2 paralelos.
    expect(option.maxPanelsPerString, equals(12));
    expect(option.maxParallelStringsPerMppt, equals(2));
    expect(option.requiredStrings, equals(2)); // ceil(20/12)
    expect(option.isStringConfigurationCompatible, isTrue);
    expect(option.isCompatible, isTrue);
  });

  test('el fusible DC es Isc x 1.25 redondeado al siguiente valor comercial',
      () {
    final option = calculateOption();
    final fuse = option.dcFuseRecommendation;

    expect(fuse, isNotNull);
    expect(fuse!.calculatedFuseAmps, closeTo(12.5, 0.001)); // 10 x 1.25
    expect(fuse.suggestedCommercialFuseAmps, equals(15)); // siguiente >= 12.5
  });

  test('el cable y la tuberia DC se dimensionan con la corriente de diseño',
      () {
    final option = calculateOption();
    final cable = option.dcCableRecommendation;
    final conduit = option.dcConduitRecommendation;

    expect(cable, isNotNull);
    expect(cable!.requiredStrings, equals(2));
    expect(cable.totalConductors, equals(6)); // 2 strings x 3 conductores
    expect(conduit, isNotNull);
    // Tabla base para 6 conductores dá 3/4"; se suma 1/4" de holgura.
    expect(conduit!.suggestedConduitTradeSize, equals('1"'));
    expect(conduit.isStockedInCatalog, isTrue);
  });

  test('sin Voc/Isc del panel no se puede validar la configuracion de strings',
      () {
    final panelSinDatos = SolarPanel(
      id: 'panel-2',
      brand: 'Test',
      model: 'Sin datos',
      powerWatts: 400,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    final result = ElectricalDimensioningRules.calculate(
      ElectricalDimensioningInput(
        requiredPanels: 20,
        panelPowerWatts: panelSinDatos.powerWatts,
        selectedPanel: panelSinDatos,
        inverters: [inverter],
      ),
    );

    final option = result.options.single;

    expect(option.hasPanelTechnicalData, isFalse);
    expect(option.isCompatible, isFalse);
    expect(option.warnings, isNotEmpty);
  });

  test('el cable AC respeta el limite de caida de tension de 3%', () {
    final option = calculateOption();

    final recommendation = ElectricalDimensioningRules.calculateAcCableRecommendation(
      option: option,
      input: const ElectricalAcInput(
        distanceMeters: 10,
        material: AcConductorMaterial.copper,
        phaseType: AcPhaseType.bifasic,
        voltage: 220,
      ),
    );

    expect(recommendation, isNotNull);
    expect(recommendation!.isVoltageDropOk, isTrue);
    expect(recommendation.voltageDropPercent, lessThanOrEqualTo(3));
  });

  test('a mayor distancia se recomienda un calibre AC mas grueso', () {
    final option = calculateOption();

    final shortDistance = ElectricalDimensioningRules.calculateAcCableRecommendation(
      option: option,
      input: const ElectricalAcInput(
        distanceMeters: 5,
        material: AcConductorMaterial.copper,
        phaseType: AcPhaseType.bifasic,
        voltage: 220,
      ),
    );

    final longDistance = ElectricalDimensioningRules.calculateAcCableRecommendation(
      option: option,
      input: const ElectricalAcInput(
        distanceMeters: 150,
        material: AcConductorMaterial.copper,
        phaseType: AcPhaseType.bifasic,
        voltage: 220,
      ),
    );

    expect(shortDistance, isNotNull);
    expect(longDistance, isNotNull);
    expect(
      longDistance!.conductorAreaMm2,
      greaterThanOrEqualTo(shortDistance!.conductorAreaMm2),
    );
  });
}
