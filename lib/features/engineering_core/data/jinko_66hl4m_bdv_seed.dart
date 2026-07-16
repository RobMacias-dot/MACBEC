import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/local/database/app_database.dart';
import 'mec_repository.dart';

const jinko66hl4mBdvPanelId = 'mec-jinko-66hl4m-bdv';
const _revisionCode = 'datasheet-confirmed-66hl4m-bdv';

/// Seed idempotente del primer gemelo digital MEC confirmado por datasheet.
class Jinko66hl4mBdvSeed {
  const Jinko66hl4mBdvSeed._();

  static Future<void> ensureSeeded(AppDatabase database) async {
    final repository = MecRepository(database);
    await database.transaction(() async {
      final existingPanel = await (database.select(database.panels)
            ..where((row) => row.id.equals(jinko66hl4mBdvPanelId)))
          .getSingleOrNull();
      if (existingPanel == null) {
        await database.into(database.panels).insert(
              PanelsCompanion.insert(
                id: const Value(jinko66hl4mBdvPanelId),
                brand: 'Jinko Solar',
                model: '66HL4M-BDV',
                powerWatts: 620,
                voc: const Value(49.08),
                isc: const Value(16.08),
                vmp: const Value(40.74),
                imp: const Value(15.22),
                efficiency: const Value(22.95),
                lengthMm: const Value(2382),
                widthMm: const Value(1134),
                thicknessMm: const Value(30),
                isActive: const Value(true),
              ),
            );
      }

      final existingRevision =
          await (database.select(database.technicalProductRevisions)
                ..where(
                  (row) =>
                      row.panelId.equals(jinko66hl4mBdvPanelId) &
                      row.revisionCode.equals(_revisionCode),
                ))
              .getSingleOrNull();
      if (existingRevision != null) return;

      final document = await repository.saveTechnicalDocument(
        TechnicalDocumentsCompanion.insert(
          source: 'Jinko Solar datasheet supplied for MEC validation',
          sourceVersion: const Value('66HL4M-BDV'),
          fileName: 'Jinko_66HL4M-BDV_datasheet',
          verificationStatus: 'confirmed_datasheet',
          confidenceLevel: 'high',
        ),
      );
      final revision = await repository.saveProductRevision(
        TechnicalProductRevisionsCompanion.insert(
          panelId: jinko66hl4mBdvPanelId,
          revisionCode: _revisionCode,
          sourceDocumentId: Value(document.id),
          verificationStatus: 'confirmed_datasheet',
          confidenceLevel: 'high',
          effectiveAt: DateTime.utc(2026, 7, 16),
        ),
      );
      await repository.savePanelSpecification(
        PanelTechnicalSpecificationsCompanion.insert(
          productRevisionId: revision.id,
          technology: const Value(
            'N-type TOPCon, bifacial double-glass monocrystalline',
          ),
          cellCount: const Value(132),
          vmp: const Value(40.74),
          imp: const Value(15.22),
          efficiencyPercent: const Value(22.95),
          pmaxTemperatureCoefficientPerC: const Value(-0.0029),
          vocTemperatureCoefficientPerC: const Value(-0.0025),
          iscTemperatureCoefficientPerC: const Value(0.00045),
          noctCelsius: const Value(45),
          weightKg: const Value(32.4),
          maxSystemVoltage: const Value(1500),
          maxSeriesFuseAmps: const Value(35),
          minOperatingTemperatureCelsius: const Value(-40),
          maxOperatingTemperatureCelsius: const Value(85),
          frontLoadPa: const Value(5400),
          rearLoadPa: const Value(2400),
          specificationJson: Value(
            jsonEncode(
              const {
                'powerTolerance': '0 to +3%',
                'frame': 'anodized aluminum',
                'frontGlassMm': 2.0,
                'rearGlassMm': 2.0,
                'junctionBox': 'IP68',
                'connector': 'JK03M / MC4',
                'cableMm2': 4.0,
                'positiveCableMm': 400,
                'negativeCableMm': 200,
                'productWarrantyYears': 12,
                'linearPowerWarrantyYears': 30,
                'firstYearDegradationPercent': 1.0,
                'annualDegradationPercent': 0.40,
                'bifacialityReferencePercent': 80,
                'bifacialityIscPercent': 80,
                'bifacialityPmaxPercent': 80,
                'bifacialityVocPercent': 98,
              },
            ),
          ),
        ),
      );
      for (final evidence in const {
        'pmaxWatts': '620 W',
        'vocVolts': '49.08 V',
        'iscAmps': '16.08 A',
        'vmpVolts': '40.74 V',
        'impAmps': '15.22 A',
        'vocTemperatureCoefficientPerC': '-0.25 %/°C (-0.0025 /°C)',
        'maxSystemVoltage': '1500 VDC',
        'maxSeriesFuseAmps': '35 A',
      }.entries) {
        await database.into(database.technicalFieldEvidence).insert(
              TechnicalFieldEvidenceCompanion.insert(
                productRevisionId: revision.id,
                fieldKey: evidence.key,
                valueText: evidence.value,
                valueStatus: 'confirmed_datasheet',
                sourceDocumentId: Value(document.id),
              ),
            );
      }
    });
  }
}
