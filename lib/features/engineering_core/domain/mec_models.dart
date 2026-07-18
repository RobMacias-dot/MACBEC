enum MecDataStatus {
  confirmedDatasheet,
  commercialCatalog,
  calculated,
  partial,
  pendingDatasheet,
  pendingFieldValidation
}

enum MecConfidenceLevel { high, medium, low }

enum MecSourceType {
  manufacturerDatasheet,
  commercialCatalog,
  engineeringRule,
  fieldMeasurement,
  manualEntry
}

enum MecValueStatus { confirmed, derived, missing }

enum MecValidationSeverity { warning, blocking }

class MecSourceReference {
  const MecSourceReference(
      {required this.id,
      required this.type,
      required this.title,
      this.manufacturer,
      this.documentVersion,
      this.documentDate,
      this.fileName,
      this.url,
      this.page,
      this.sha256,
      this.notes});
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
  const MecValue(
      {required this.value,
      required this.status,
      required this.confidence,
      this.unit,
      this.sourceId,
      this.sourcePage,
      this.reviewedAt,
      this.reviewedBy,
      this.notes});
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
      value != null && isConfirmed && confidence == MecConfidenceLevel.high;
}

class MecProductIdentity {
  const MecProductIdentity(
      {required this.id,
      required this.category,
      required this.brand,
      required this.model,
      required this.description,
      this.family,
      this.sku,
      this.active = true,
      this.revision = 1});
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
  const MecPanelSpecification(
      {required this.product,
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
      this.notes});

  factory MecPanelSpecification.legacy(
          {required String panelId,
          required String manufacturer,
          required String model,
          required double pmaxWatts,
          required double vocVolts,
          required double iscAmps,
          required double vmpVolts,
          required double impAmps,
          required double maxSystemVoltage,
          required double maxSeriesFuseAmps,
          double? vocTemperatureCoefficientPerC}) =>
      MecPanelSpecification(
          product: MecProductIdentity(
              id: panelId,
              category: 'panel',
              brand: manufacturer,
              model: model,
              description: model),
          pmaxW: MecValue(
              value: pmaxWatts,
              status: MecDataStatus.confirmedDatasheet,
              confidence: MecConfidenceLevel.high),
          vmpV: MecValue(
              value: vmpVolts,
              status: MecDataStatus.confirmedDatasheet,
              confidence: MecConfidenceLevel.high),
          impA: MecValue(
              value: impAmps,
              status: MecDataStatus.confirmedDatasheet,
              confidence: MecConfidenceLevel.high),
          vocV: MecValue(
              value: vocVolts,
              status: MecDataStatus.confirmedDatasheet,
              confidence: MecConfidenceLevel.high),
          iscA: MecValue(
              value: iscAmps,
              status: MecDataStatus.confirmedDatasheet,
              confidence: MecConfidenceLevel.high),
          lengthMm: MecValue(
              value: null,
              status: MecDataStatus.pendingDatasheet,
              confidence: MecConfidenceLevel.low),
          widthMm: MecValue(
              value: null,
              status: MecDataStatus.pendingDatasheet,
              confidence: MecConfidenceLevel.low),
          thicknessMm: MecValue(
              value: null,
              status: MecDataStatus.pendingDatasheet,
              confidence: MecConfidenceLevel.low),
          weightKg: MecValue(
              value: null,
              status: MecDataStatus.pendingDatasheet,
              confidence: MecConfidenceLevel.low),
          temperatureCoefficientPmaxPctC: MecValue(
              value: null,
              status: MecDataStatus.pendingDatasheet,
              confidence: MecConfidenceLevel.low),
          temperatureCoefficientVocPctC: MecValue(
              value: vocTemperatureCoefficientPerC == null
                  ? null
                  : vocTemperatureCoefficientPerC * 100,
              status: vocTemperatureCoefficientPerC == null
                  ? MecDataStatus.pendingDatasheet
                  : MecDataStatus.confirmedDatasheet,
              confidence: vocTemperatureCoefficientPerC == null
                  ? MecConfidenceLevel.low
                  : MecConfidenceLevel.high),
          temperatureCoefficientIscPctC: MecValue(
              value: null,
              status: MecDataStatus.pendingDatasheet,
              confidence: MecConfidenceLevel.low),
          maxSystemVoltageV: MecValue(
              value: maxSystemVoltage,
              status: MecDataStatus.confirmedDatasheet,
              confidence: MecConfidenceLevel.high),
          maxSeriesFuseA: MecValue(
              value: maxSeriesFuseAmps,
              status: MecDataStatus.confirmedDatasheet,
              confidence: MecConfidenceLevel.high));

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
  double get vocVolts => vocV.value!;
}

class MecCompatibilityRule {
  const MecCompatibilityRule(
      {required this.id,
      required this.originType,
      required this.targetType,
      required this.ruleCode,
      required this.severity,
      required this.description,
      required this.sourceId,
      this.active = true});
  final String id;
  final String originType;
  final String targetType;
  final String ruleCode;
  final String severity;
  final String description;
  final String sourceId;
  final bool active;
}

class MecCalculatedValue {
  const MecCalculatedValue(
      {required this.value, required this.status, required this.description});
  final double? value;
  final MecValueStatus status;
  final String description;
}

class MecValidationIssue {
  const MecValidationIssue({required this.severity, required this.message});
  final MecValidationSeverity severity;
  final String message;
  bool get blocksCalculation => severity == MecValidationSeverity.blocking;
}

class MecStringAssessment {
  const MecStringAssessment(
      {required this.installedDcPower,
      required this.coldVoc,
      required this.stringVmp,
      required this.parallelIsc,
      required this.issues});
  final MecCalculatedValue installedDcPower;
  final MecCalculatedValue coldVoc;
  final MecCalculatedValue stringVmp;
  final MecCalculatedValue parallelIsc;
  final List<MecValidationIssue> issues;
  bool get canCalculate => !issues.any((issue) => issue.blocksCalculation);
}
