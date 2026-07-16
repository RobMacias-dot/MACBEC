enum MecDataStatus {
  confirmedDatasheet,
  commercialCatalog,
  calculated,
  partial,
  pendingDatasheet,
  pendingFieldValidation,
}

enum MecConfidenceLevel { high, medium, low }

enum MecSourceType {
  manufacturerDatasheet,
  commercialCatalog,
  engineeringRule,
  fieldMeasurement,
  manualEntry,
}

class MecSourceReference {
  const MecSourceReference({
    required this.id,
    required this.type,
    required this.title,
    this.manufacturer,
    this.documentVersion,
    this.documentDate,
    this.fileName,
    this.url,
    this.page,
    this.sha256,
    this.notes,
  });

  final String id;
  final MecSourceType type;
  final String title;
  final String? manufacturer;
  final String? documentVersion;
  final DateTime? documentDate;
  final String? fileName;
  final String? url;
  final int? page;
  final String? sha256;
  final String? notes;
}

class MecValue<T> {
  const MecValue({
    required this.value,
    required this.status,
    required this.confidence,
    this.unit,
    this.sourceId,
    this.sourcePage,
    this.reviewedAt,
    this.reviewedBy,
    this.notes,
  });

  final T? value;
  final String? unit;
  final MecDataStatus status;
  final MecConfidenceLevel confidence;
  final String? sourceId;
  final int? sourcePage;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? notes;

  bool get isConfirmed => status == MecDataStatus.confirmedDatasheet;
  bool get canDriveCriticalCalculation =>
      value != null &&
      status == MecDataStatus.confirmedDatasheet &&
      confidence == MecConfidenceLevel.high;
}

class MecProductIdentity {
  const MecProductIdentity({
    required this.id,
    required this.category,
    required this.brand,
    required this.model,
    required this.description,
    this.family,
    this.sku,
    this.active = true,
    this.revision = 1,
  });

  final String id;
  final String category;
  final String brand;
  final String model;
  final String description;
  final String? family;
  final String? sku;
  final bool active;
  final int revision;
}

class MecPanelSpecification {
  const MecPanelSpecification({
    required this.product,
    required this.pmaxW,
    required this.vmpV,
    required this.impA,
    required this.vocV,
    required this.iscA,
    required this.lengthMm,
    required this.widthMm,
    required this.thicknessMm,
    required this.weightKg,
    required this.temperatureCoefficientPmaxPctC,
    required this.temperatureCoefficientVocPctC,
    required this.temperatureCoefficientIscPctC,
    required this.maxSystemVoltageV,
    required this.maxSeriesFuseA,
    this.efficiencyPct,
    this.noctC,
    this.cellTechnology,
    this.cellCount,
    this.bifacial,
    this.frontLoadPa,
    this.rearLoadPa,
    this.junctionBoxIp,
    this.connector,
    this.outputCableAreaMm2,
    this.productWarrantyYears,
    this.performanceWarrantyYears,
    this.sourceIds = const [],
    this.notes,
  });

  final MecProductIdentity product;
  final MecValue<double> pmaxW;
  final MecValue<double> vmpV;
  final MecValue<double> impA;
  final MecValue<double> vocV;
  final MecValue<double> iscA;
  final MecValue<double> lengthMm;
  final MecValue<double> widthMm;
  final MecValue<double> thicknessMm;
  final MecValue<double> weightKg;
  final MecValue<double> temperatureCoefficientPmaxPctC;
  final MecValue<double> temperatureCoefficientVocPctC;
  final MecValue<double> temperatureCoefficientIscPctC;
  final MecValue<double> maxSystemVoltageV;
  final MecValue<double> maxSeriesFuseA;
  final MecValue<double>? efficiencyPct;
  final MecValue<double>? noctC;
  final MecValue<String>? cellTechnology;
  final MecValue<int>? cellCount;
  final MecValue<bool>? bifacial;
  final MecValue<double>? frontLoadPa;
  final MecValue<double>? rearLoadPa;
  final MecValue<String>? junctionBoxIp;
  final MecValue<String>? connector;
  final MecValue<double>? outputCableAreaMm2;
  final MecValue<int>? productWarrantyYears;
  final MecValue<int>? performanceWarrantyYears;
  final List<String> sourceIds;
  final String? notes;

  bool get isReadyForStringSizing =>
      pmaxW.canDriveCriticalCalculation &&
      vmpV.canDriveCriticalCalculation &&
      impA.canDriveCriticalCalculation &&
      vocV.canDriveCriticalCalculation &&
      iscA.canDriveCriticalCalculation &&
      temperatureCoefficientVocPctC.canDriveCriticalCalculation;

  bool get isReadyForStructure =>
      lengthMm.canDriveCriticalCalculation &&
      widthMm.canDriveCriticalCalculation &&
      thicknessMm.canDriveCriticalCalculation &&
      weightKg.canDriveCriticalCalculation;
}

class MecCompatibilityRule {
  const MecCompatibilityRule({
    required this.id,
    required this.originType,
    required this.targetType,
    required this.ruleCode,
    required this.severity,
    required this.description,
    required this.sourceId,
    this.active = true,
  });

  final String id;
  final String originType;
  final String targetType;
  final String ruleCode;
  final String severity;
  final String description;
  final String sourceId;
  final bool active;
}
