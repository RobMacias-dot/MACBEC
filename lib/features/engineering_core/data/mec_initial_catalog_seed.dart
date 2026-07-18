import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/local/database/app_database.dart';
import 'mec_repository.dart';

/// Catálogo técnico inicial utilizable sin depender de un Excel comercial.
/// Los precios se dejan vacíos deliberadamente: una ficha no es una lista de
/// precios y no debe alterar una cotización.
class MecInitialCatalogSeed {
  const MecInitialCatalogSeed._();

  static Future<void> ensureSeeded(AppDatabase database) async {
    final repository = MecRepository(database);
    await database.transaction(() async {
      final jinkoDocument = await _ensureDocument(
        database,
        source: 'Jinko Solar official datasheet',
        sourceVersion: 'JKM580-605N-72HL4-(V)-F8-EN',
        fileName: 'JKM580-605N-72HL4-(V)-F8-EN.pdf',
        localPath:
            'https://www.jinkosolar.com/uploads/JKM580-605N-72HL4-%28V%29-F8-EN.pdf',
      );
      for (final panel in _jinkoPanels) {
        await _ensurePanel(
          database: database,
          repository: repository,
          documentId: jinkoDocument.id,
          panel: panel,
        );
      }

      final growattDocument = await _ensureDocument(
        database,
        source: 'Growatt official datasheet',
        sourceVersion: 'MIN_3000-7600TL-XH-US_Datasheet_EN_202402',
        fileName: 'MIN_3000-7600TL-XH-US_Datasheet_EN_202402.pdf',
        localPath:
            'https://us.growatt.com/upload/file/MIN_3000-7600TL-XH-US_Datasheet_EN_202402.pdf',
      );
      for (final inverter in _growattInverters) {
        await _ensureInverter(
          database: database,
          repository: repository,
          documentId: growattDocument.id,
          inverter: inverter,
        );
      }
    });
  }

  static Future<TechnicalDocument> _ensureDocument(
    AppDatabase database, {
    required String source,
    required String sourceVersion,
    required String fileName,
    required String localPath,
  }) async {
    final existing = await (database.select(database.technicalDocuments)
          ..where((row) => row.fileName.equals(fileName)))
        .getSingleOrNull();
    if (existing != null) return existing;
    return database.into(database.technicalDocuments).insertReturning(
          TechnicalDocumentsCompanion.insert(
            source: source,
            sourceVersion: Value(sourceVersion),
            localPath: Value(localPath),
            fileName: fileName,
            verificationStatus: 'confirmed_datasheet',
            confidenceLevel: 'high',
            publishedAt: Value(DateTime.utc(2026, 7, 17)),
          ),
        );
  }

  static Future<void> _ensurePanel({
    required AppDatabase database,
    required MecRepository repository,
    required String documentId,
    required _PanelSeed panel,
  }) async {
    final existing = await (database.select(database.panels)
          ..where((row) => row.id.equals(panel.id)))
        .getSingleOrNull();
    if (existing != null) return;
    await database.into(database.panels).insert(
          PanelsCompanion.insert(
            id: Value(panel.id),
            brand: 'Jinko Solar',
            model: panel.model,
            powerWatts: panel.powerWatts,
            voc: Value(panel.voc),
            isc: Value(panel.isc),
            vmp: Value(panel.vmp),
            imp: Value(panel.imp),
            efficiency: Value(panel.efficiency),
            lengthMm: const Value(2278),
            widthMm: const Value(1134),
            thicknessMm: const Value(30),
            isActive: const Value(true),
          ),
        );
    final revision = await repository.saveProductRevision(
      TechnicalProductRevisionsCompanion.insert(
        panelId: panel.id,
        revisionCode: 'jinko-72hl4-v-2024',
        sourceDocumentId: Value(documentId),
        verificationStatus: 'confirmed_datasheet',
        confidenceLevel: 'high',
        effectiveAt: DateTime.utc(2026, 7, 17),
      ),
    );
    await repository.savePanelSpecification(
      PanelTechnicalSpecificationsCompanion.insert(
        productRevisionId: revision.id,
        technology: const Value('N-type TOPCon monocrystalline'),
        cellCount: const Value(144),
        vmp: Value(panel.vmp),
        imp: Value(panel.imp),
        efficiencyPercent: Value(panel.efficiency),
        pmaxTemperatureCoefficientPerC: const Value(-0.0029),
        vocTemperatureCoefficientPerC: const Value(-0.0025),
        iscTemperatureCoefficientPerC: const Value(0.00045),
        noctCelsius: const Value(45),
        weightKg: const Value(27),
        maxSystemVoltage: const Value(1500),
        maxSeriesFuseAmps: const Value(25),
        minOperatingTemperatureCelsius: const Value(-40),
        maxOperatingTemperatureCelsius: const Value(70),
        frontLoadPa: const Value(5400),
        rearLoadPa: const Value(2400),
        specificationJson: Value(jsonEncode(<String, Object>{
          'junctionBox': 'IP68',
          'connector': 'JK03M / MC4 / others',
          'outputCableMm2': 4.0,
          'productWarrantyYears': 12,
          'performanceWarrantyYears': 30,
        })),
      ),
    );
    for (final entry in panel.evidence.entries) {
      await database.into(database.technicalFieldEvidence).insert(
            TechnicalFieldEvidenceCompanion.insert(
              productRevisionId: revision.id,
              fieldKey: entry.key,
              valueText: entry.value,
              valueStatus: 'confirmed_datasheet',
              sourceDocumentId: Value(documentId),
              sourceLocator: const Value('p. 2 / STC'),
            ),
          );
    }
  }

  static Future<void> _ensureInverter({
    required AppDatabase database,
    required MecRepository repository,
    required String documentId,
    required _InverterSeed inverter,
  }) async {
    final existing = await (database.select(database.inverters)
          ..where((row) => row.id.equals(inverter.id)))
        .getSingleOrNull();
    if (existing != null) return;
    await database.into(database.inverters).insert(
          InvertersCompanion.insert(
            id: Value(inverter.id),
            brand: 'Growatt',
            model: inverter.model,
            nominalPowerWatts: inverter.nominalPowerWatts,
            maxPvPowerWatts: Value(inverter.maxPvPowerWatts),
            maxDcVoltage: const Value(600),
            maxShortCircuitCurrentPerMppt: const Value(16.9),
            maxOutputCurrent: Value(inverter.maxOutputCurrent),
            mpptCount: Value(inverter.mpptCount),
          ),
        );
    final revision = await repository.saveInverterRevision(
      TechnicalInverterRevisionsCompanion.insert(
        inverterId: inverter.id,
        revisionCode: 'growatt-min-xh-us-2024',
        sourceDocumentId: Value(documentId),
        verificationStatus: 'confirmed_datasheet',
        confidenceLevel: 'high',
        effectiveAt: DateTime.utc(2026, 7, 17),
      ),
    );
    await repository.saveInverterSpecification(
      InverterTechnicalSpecificationsCompanion.insert(
        productRevisionId: revision.id,
        mpptMinVoltage: Value(inverter.mpptMinVoltage),
        mpptMaxVoltage: const Value(500),
        startupVoltage: const Value(80),
        nominalDcVoltage: const Value(360),
        maxInputCurrentPerMppt: const Value(12.5),
        stringsPerMppt: const Value(2),
        maxEfficiencyPercent: const Value(98.4),
        gridConnection: const Value('Monofásica 208/240 Vac, 60 Hz'),
        protectionRating: const Value('NEMA 4X'),
        specificationJson: Value(jsonEncode(<String, Object>{
          'dcAcRatio': 2,
          'maxShortCircuitCurrentPerMpptA': 16.9,
          'sourceScope': 'US 208/240 Vac version',
        })),
      ),
    );
  }

  static const _jinkoPanels = <_PanelSeed>[
    _PanelSeed('mec-jinko-580n-72hl4-v', 'JKM580N-72HL4-V', 580, 43.35, 13.38,
        52.31, 14.01, 22.45),
    _PanelSeed('mec-jinko-585n-72hl4-v', 'JKM585N-72HL4-V', 585, 43.53, 13.44,
        52.47, 14.07, 22.65),
    _PanelSeed('mec-jinko-590n-72hl4-v', 'JKM590N-72HL4-V', 590, 43.71, 13.50,
        52.63, 14.13, 22.84),
    _PanelSeed('mec-jinko-595n-72hl4-v', 'JKM595N-72HL4-V', 595, 43.88, 13.56,
        52.79, 14.19, 23.03),
  ];

  static const _growattInverters = <_InverterSeed>[
    _InverterSeed('mec-growatt-min-3000tl-xh-us', 'MIN 3000TL-XH-US', 3000,
        6000, 12.5, 120, 2),
    _InverterSeed('mec-growatt-min-3800tl-xh-us', 'MIN 3800TL-XH-US', 3800,
        7600, 15.8, 150, 2),
    _InverterSeed('mec-growatt-min-5000tl-xh-us', 'MIN 5000TL-XH-US', 5000,
        10000, 20.8, 200, 2),
    _InverterSeed('mec-growatt-min-6000tl-xh-us', 'MIN 6000TL-XH-US', 6000,
        12000, 25.0, 160, 3),
    _InverterSeed('mec-growatt-min-7600tl-xh-us', 'MIN 7600TL-XH-US', 7600,
        15200, 31.7, 200, 3),
  ];
}

class _PanelSeed {
  const _PanelSeed(this.id, this.model, this.powerWatts, this.vmp, this.imp,
      this.voc, this.isc, this.efficiency);
  final String id;
  final String model;
  final double powerWatts;
  final double vmp;
  final double imp;
  final double voc;
  final double isc;
  final double efficiency;
  Map<String, String> get evidence => {
        'pmaxWatts': '$powerWatts W',
        'vmpVolts': '$vmp V',
        'impAmps': '$imp A',
        'vocVolts': '$voc V',
        'iscAmps': '$isc A',
        'efficiencyPercent': '$efficiency %'
      };
}

class _InverterSeed {
  const _InverterSeed(
      this.id,
      this.model,
      this.nominalPowerWatts,
      this.maxPvPowerWatts,
      this.maxOutputCurrent,
      this.mpptMinVoltage,
      this.mpptCount);
  final String id;
  final String model;
  final double nominalPowerWatts;
  final double maxPvPowerWatts;
  final double maxOutputCurrent;
  final double mpptMinVoltage;
  final int mpptCount;
}
