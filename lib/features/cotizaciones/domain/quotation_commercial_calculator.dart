import '../../catalogo_tecnico/domain/entities/solar_inverter.dart';
import '../../catalogo_tecnico/domain/entities/solar_panel.dart';
import 'entities/quotation_commercial_quote.dart';
import 'quotation_rules.dart';

/// Calcula el desglose comercial de una cotización a partir del panel y el
/// inversor seleccionados. Solo paneles e inversor tienen costo de compra
/// persistido hoy; estructura, cableado y mano de obra se incorporarán en
/// una fase posterior cuando esos catálogos tengan datos comerciales.
class QuotationCommercialCalculator {
  const QuotationCommercialCalculator._();

  static SaveQuotationCommercialQuoteInput calculate({
    required SolarPanel panel,
    required int panelQuantity,
    required SolarInverter inverter,
    required int inverterQuantity,
    required double generalUtilityRatePercent,
    required double ivaRatePercent,
    required double discountAmount,
    required double advancePaymentAmount,
    required String currency,
  }) {
    final utilityRate = generalUtilityRatePercent / 100;
    final ivaRate = ivaRatePercent / 100;

    final panelUnitCost = panel.purchasePrice ?? 0;
    final panelUnitPrice = QuotationRules.applyUtility(
      panelUnitCost,
      utilityRate,
    );

    final inverterUnitCost = inverter.purchasePrice ?? 0;
    final inverterUnitPrice = QuotationRules.applyUtility(
      inverterUnitCost,
      utilityRate,
    );

    final subtotal = (panelUnitPrice * panelQuantity) +
        (inverterUnitPrice * inverterQuantity);

    final safeDiscount = discountAmount.clamp(0, subtotal).toDouble();

    final ivaAmount = QuotationRules.calculateIva(
      subtotal - safeDiscount,
      ivaRate,
    );

    final total = QuotationRules.calculateTotal(
      subtotal: subtotal,
      ivaRate: ivaRate,
      discountAmount: safeDiscount,
    );

    return SaveQuotationCommercialQuoteInput(
      generalUtilityRatePercent: generalUtilityRatePercent,
      ivaRatePercent: ivaRatePercent,
      discountAmount: safeDiscount,
      advancePaymentAmount: advancePaymentAmount,
      currency: currency,
      panelUnitCost: panelUnitCost,
      panelUnitPrice: panelUnitPrice,
      panelQuantity: panelQuantity,
      inverterUnitCost: inverterUnitCost,
      inverterUnitPrice: inverterUnitPrice,
      inverterQuantity: inverterQuantity,
      subtotal: subtotal,
      ivaAmount: ivaAmount,
      total: total,
    );
  }
}
