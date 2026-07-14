import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalogo_tecnico/application/inverter_catalog_controller.dart';
import '../../catalogo_tecnico/application/panel_catalog_controller.dart';
import '../../catalogo_tecnico/domain/entities/solar_inverter.dart';
import '../../catalogo_tecnico/domain/entities/solar_panel.dart';
import '../../clientes/application/clients_controller.dart';
import '../../clientes/data/client_fiscal_repository.dart';
import '../../clientes/domain/entities/client.dart';
import '../../clientes/domain/entities/client_fiscal_profile.dart';
import '../../proyectos/application/projects_controller.dart';
import '../../proyectos/domain/entities/project.dart';
import 'company_settings_repository.dart';
import '../domain/entities/company_profile.dart';

final seedDataServiceProvider = Provider<SeedDataService>((ref) {
  return SeedDataService(ref);
});

/// Carga datos de ejemplo (catálogo, cliente, proyecto, empresa) para poder
/// probar el flujo completo de la app sin capturar todo a mano. Pensado
/// solo para pruebas locales/demo, no para producción.
class SeedDataService {
  SeedDataService(this._ref);

  final Ref _ref;

  Future<void> seedSampleData() async {
    await _seedCompanyProfile();
    final clientId = await _seedClientWithFiscalData();
    await _seedProject(clientId);
    await _seedPanels();
    await _seedInverters();
  }

  Future<void> _seedCompanyProfile() async {
    final repository = _ref.read(companySettingsRepositoryProvider);
    final existing = await repository.getCompanyProfile();

    if (existing != null && existing.hasData) return;

    await repository.saveCompanyProfile(
      const CompanyProfile(
        id: null,
        companyName: 'MacBec Soluciones en Energía',
        rfc: 'MSE010101AAA',
        phone: '4421234567',
        email: 'contacto@macbec.mx',
        address: 'Av. Ejemplo 123, Querétaro, Qro.',
      ),
    );
  }

  Future<String> _seedClientWithFiscalData() async {
    final clientRepository = _ref.read(clientRepositoryProvider);
    final existingClients = await clientRepository.getAll();

    for (final client in existingClients) {
      if (client.fullName == 'Cliente de prueba') {
        return client.id;
      }
    }

    final clientId = await clientRepository.create(
      const SaveClientInput(
        fullName: 'Cliente de prueba',
        phone: '4427654321',
        email: 'cliente.prueba@example.com',
        address: 'Calle Falsa 123, Col. Centro, Querétaro, Qro.',
        notes: 'Cliente sembrado para pruebas del flujo completo.',
      ),
    );

    await _ref.read(clientFiscalRepositoryProvider).upsert(
          clientId: clientId,
          input: const SaveClientFiscalProfileInput(
            rfc: 'XAXX010101000',
            legalName: 'Cliente de Prueba SA de CV',
            fiscalRegime: '601',
            fiscalZipCode: '76000',
            cfdiUse: 'G03',
            invoiceEmail: 'facturacion.prueba@example.com',
          ),
        );

    return clientId;
  }

  Future<void> _seedProject(String clientId) async {
    final repository = _ref.read(projectRepositoryProvider);
    final existingProjects = await repository.getByClientId(clientId);

    if (existingProjects.isNotEmpty) return;

    await repository.create(
      SaveProjectInput(
        clientId: clientId,
        name: 'Proyecto de prueba - Residencial',
        installationType: InstallationType.sfvi,
        serviceAddress: 'Calle Falsa 123, Col. Centro, Querétaro, Qro.',
        state: 'Querétaro',
        municipality: 'Querétaro',
        notes: 'Proyecto sembrado para pruebas del flujo completo.',
      ),
    );
  }

  Future<void> _seedPanels() async {
    final repository = _ref.read(panelCatalogRepositoryProvider);
    final existing = await repository.getAllPanels();

    final samples = <SaveSolarPanelInput>[
      const SaveSolarPanelInput(
        brand: 'Jinko Solar',
        model: 'Tiger Neo 585W',
        powerWatts: 585,
        voc: 51.5,
        isc: 14.15,
        lengthMm: 2278,
        widthMm: 1134,
        thicknessMm: 30,
        purchasePrice: 2200,
        isActive: true,
      ),
      const SaveSolarPanelInput(
        brand: 'Trina Solar',
        model: 'Vertex S+ 505W',
        powerWatts: 505,
        voc: 46.8,
        isc: 13.52,
        lengthMm: 1762,
        widthMm: 1134,
        thicknessMm: 30,
        purchasePrice: 1950,
        isActive: true,
      ),
    ];

    for (final sample in samples) {
      final alreadyExists = existing.any(
        (panel) => panel.brand == sample.brand && panel.model == sample.model,
      );

      if (!alreadyExists) {
        await repository.createPanel(sample);
      }
    }
  }

  Future<void> _seedInverters() async {
    final repository = _ref.read(inverterCatalogRepositoryProvider);
    final existing = await repository.getAllInverters();

    final samples = <SaveSolarInverterInput>[
      const SaveSolarInverterInput(
        brand: 'Growatt',
        model: 'MIN 6000TL-X',
        nominalPowerWatts: 6000,
        maxPvPowerWatts: 9000,
        maxDcVoltage: 550,
        maxShortCircuitCurrentPerMppt: 16,
        maxOutputCurrent: 27.3,
        mpptCount: 2,
        purchasePrice: 9500,
      ),
      const SaveSolarInverterInput(
        brand: 'Solis',
        model: 'S6-GR1P8K',
        nominalPowerWatts: 8000,
        maxPvPowerWatts: 12000,
        maxDcVoltage: 600,
        maxShortCircuitCurrentPerMppt: 16,
        maxOutputCurrent: 36.4,
        mpptCount: 2,
        purchasePrice: 12800,
      ),
    ];

    for (final sample in samples) {
      final alreadyExists = existing.any(
        (inverter) =>
            inverter.brand == sample.brand && inverter.model == sample.model,
      );

      if (!alreadyExists) {
        await repository.createInverter(sample);
      }
    }
  }
}
