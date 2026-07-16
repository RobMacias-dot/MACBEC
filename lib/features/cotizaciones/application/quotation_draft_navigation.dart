import '../../../app/router/app_routes.dart';
import '../domain/entities/quotation_draft.dart';

/// Orden completo de los 9 pasos de un borrador de cotización. Se usa para
/// comparar el progreso de un draft contra cualquier paso dado (ver
/// [quotationDraftStepRank]).
const List<String> quotationDraftStepOrder = [
  QuotationDraftStep.prospect,
  QuotationDraftStep.cfeReceipt,
  QuotationDraftStep.cfeReview,
  QuotationDraftStep.energyAnalysis,
  QuotationDraftStep.technicalSelection,
  QuotationDraftStep.electricalDimensioning,
  QuotationDraftStep.structure,
  QuotationDraftStep.commercialQuote,
  QuotationDraftStep.clientPreview,
];

/// Posición de [step] dentro de [quotationDraftStepOrder]. `-1` si el
/// borrador todavía no tiene ningún paso completado.
int quotationDraftStepRank(String? step) {
  if (step == null) return -1;
  return quotationDraftStepOrder.indexOf(step);
}

bool isQuotationDraftComplete(QuotationDraft draft) {
  return draft.lastCompletedStep == QuotationDraftStep.clientPreview;
}

/// Traduce el último módulo completado (persistido en el borrador) a la
/// pantalla donde debe reanudarse el flujo. Devuelve `null` para
/// borradores antiguos sin este dato, dejando la inferencia por status a
/// [nextRouteForDraft].
String? routeForCompletedStep(String? lastCompletedStep) {
  switch (lastCompletedStep) {
    case QuotationDraftStep.prospect:
      return AppRoutes.reciboCfe;
    case QuotationDraftStep.cfeReceipt:
      return AppRoutes.reciboCfeRevision;
    case QuotationDraftStep.cfeReview:
      return AppRoutes.analisisConsumo;
    case QuotationDraftStep.energyAnalysis:
      return AppRoutes.seleccionTecnica;
    case QuotationDraftStep.technicalSelection:
      return AppRoutes.dimensionamientoElectrico;
    case QuotationDraftStep.electricalDimensioning:
      return AppRoutes.estructura;
    case QuotationDraftStep.structure:
      return AppRoutes.cotizacionInterna;
    case QuotationDraftStep.commercialQuote:
    case QuotationDraftStep.clientPreview:
      return AppRoutes.cotizacionClientePreview;
    default:
      return null;
  }
}

/// Resuelve la pantalla donde continuar un borrador, usada por el botón
/// "Continuar cotización" (Clientes) y para reanudar un draft pendiente.
/// Compartida para no duplicar esta lógica entre pantallas.
String nextRouteForDraft(QuotationDraft draft) {
  final stepRoute = routeForCompletedStep(draft.lastCompletedStep);
  if (stepRoute != null) return stepRoute;

  if (!draft.hasCfeReceipt ||
      draft.status == QuotationDraftStatus.receiptPending) {
    return AppRoutes.reciboCfe;
  }

  if (!draft.hasCompleteCfeReview) {
    return AppRoutes.reciboCfeRevision;
  }

  switch (draft.status) {
    case QuotationDraftStatus.quotationInProgress:
      return AppRoutes.cotizacionInterna;
    case QuotationDraftStatus.quotationSent:
    case QuotationDraftStatus.accepted:
      return AppRoutes.cotizacionClientePreview;
    case QuotationDraftStatus.cancelled:
      return AppRoutes.cotizacion;
    case QuotationDraftStatus.inAnalysis:
    case QuotationDraftStatus.receiptReceived:
    default:
      return AppRoutes.analisisConsumo;
  }
}
