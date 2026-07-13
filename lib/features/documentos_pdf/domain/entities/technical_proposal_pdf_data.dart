import 'quotation_pdf_data.dart';

class TechnicalProposalElectricalSummary {
  const TechnicalProposalElectricalSummary({
    required this.panelVoc,
    required this.panelIsc,
    required this.inverterUsagePercent,
    required this.reserveCapacityPercent,
    required this.warnings,
    this.maxPanelsPerString,
    this.maxParallelStringsPerMppt,
    this.requiredStrings,
    this.dcFuseAmps,
    this.dcCableAwg,
    this.dcConduitSize,
    this.acCableAwg,
    this.acVoltageDropPercent,
  });

  final double? panelVoc;
  final double? panelIsc;
  final int? maxPanelsPerString;
  final int? maxParallelStringsPerMppt;
  final int? requiredStrings;
  final double inverterUsagePercent;
  final double reserveCapacityPercent;
  final int? dcFuseAmps;
  final String? dcCableAwg;
  final String? dcConduitSize;
  final String? acCableAwg;
  final double? acVoltageDropPercent;
  final List<String> warnings;
}

class TechnicalProposalStructureSummary {
  const TechnicalProposalStructureSummary({
    required this.mountTypeLabel,
    required this.fixingTypeLabel,
    required this.structuresCount,
    required this.panelsHorizontal,
    required this.panelRows,
    required this.totalLegCount,
    required this.areaMetersSquared,
    required this.angleMaterialMeters,
  });

  final String mountTypeLabel;
  final String fixingTypeLabel;
  final int structuresCount;
  final int panelsHorizontal;
  final int panelRows;
  final int totalLegCount;
  final double areaMetersSquared;
  final double angleMaterialMeters;
}

class TechnicalProposalPdfData {
  const TechnicalProposalPdfData({
    required this.draftCode,
    required this.generatedAt,
    required this.company,
    required this.client,
    required this.system,
    required this.electrical,
    required this.warrantyNote,
    this.structure,
  });

  final String draftCode;
  final DateTime generatedAt;
  final QuotationPdfCompanyInfo company;
  final QuotationPdfClientInfo client;
  final QuotationPdfSystemSummary system;
  final TechnicalProposalElectricalSummary electrical;
  final TechnicalProposalStructureSummary? structure;
  final String warrantyNote;
}
