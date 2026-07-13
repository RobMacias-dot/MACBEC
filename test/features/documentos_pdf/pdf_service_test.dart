import 'package:flutter_test/flutter_test.dart';
import 'package:macbec_solar_app/features/documentos_pdf/data/pdf_service.dart';
import 'package:macbec_solar_app/features/documentos_pdf/domain/entities/quotation_pdf_data.dart';
import 'package:macbec_solar_app/features/documentos_pdf/domain/entities/structure_technical_pdf_data.dart';
import 'package:macbec_solar_app/features/estructura/domain/structure_design_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('genera el PDF tecnico estructural con sus 4 diagramas sin lanzar', () async {
    final result = StructureDesignRules.calculateInclinedFlatRoof(
      const InclinedFlatRoofInput(
        requiredPanels: 20,
        structuresCount: 1,
        panelsHorizontal: 10,
        panelRows: 2,
        panelLengthMm: 2278,
        panelWidthMm: 1134,
        inclinationDegrees: 20,
        frontLegCm: 20,
      ),
    );

    final data = StructureTechnicalPdfData(
      draftCode: 'TEST0001',
      generatedAt: DateTime(2026, 1, 1),
      company: const QuotationPdfCompanyInfo(
        companyName: 'MacBec Soluciones en Energía',
        phone: '5555555555',
        email: 'contacto@macbec.mx',
        address: 'Calle Falsa 123',
      ),
      projectLabel: 'Prospecto de prueba',
      mountTypeLabel: StructureMountType.inclinedFlatRoof.label,
      fixingTypeLabel: StructureFixingType.chemicalAnchor.label,
      panelLengthMm: 2278,
      panelWidthMm: 1134,
      result: result,
    );

    final bytes = await PdfService().generateStructuralPdf(data);

    expect(bytes, isNotEmpty);
    // Encabezado de un PDF válido.
    expect(String.fromCharCodes(bytes.take(5)), equals('%PDF-'));
  });

  test('genera el PDF con un solo panel (patas y separaciones mínimas)',
      () async {
    final result = StructureDesignRules.calculateInclinedFlatRoof(
      const InclinedFlatRoofInput(
        requiredPanels: 1,
        structuresCount: 1,
        panelsHorizontal: 1,
        panelRows: 1,
        panelLengthMm: 2278,
        panelWidthMm: 1134,
        inclinationDegrees: 15,
        frontLegCm: 15,
      ),
    );

    final data = StructureTechnicalPdfData(
      draftCode: 'TEST0002',
      generatedAt: DateTime(2026, 1, 1),
      company: const QuotationPdfCompanyInfo(
        companyName: 'MacBec Soluciones en Energía',
        phone: '',
        email: '',
        address: '',
      ),
      projectLabel: 'Un solo módulo',
      mountTypeLabel: StructureMountType.inclinedFlatRoof.label,
      fixingTypeLabel: StructureFixingType.mechanicalAnchor.label,
      panelLengthMm: 2278,
      panelWidthMm: 1134,
      result: result,
    );

    final bytes = await PdfService().generateStructuralPdf(data);

    expect(bytes, isNotEmpty);
  });
}
