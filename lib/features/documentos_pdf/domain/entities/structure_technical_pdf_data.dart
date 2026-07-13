import '../../../estructura/domain/structure_design_rules.dart';
import 'quotation_pdf_data.dart';

class StructureTechnicalPdfData {
  const StructureTechnicalPdfData({
    required this.draftCode,
    required this.generatedAt,
    required this.company,
    required this.projectLabel,
    required this.mountTypeLabel,
    required this.fixingTypeLabel,
    required this.panelLengthMm,
    required this.panelWidthMm,
    required this.result,
  });

  final String draftCode;
  final DateTime generatedAt;
  final QuotationPdfCompanyInfo company;
  final String projectLabel;
  final String mountTypeLabel;
  final String fixingTypeLabel;
  final double panelLengthMm;
  final double panelWidthMm;
  final InclinedFlatRoofResult result;
}
