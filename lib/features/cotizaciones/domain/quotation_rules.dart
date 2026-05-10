class QuotationRules {
  const QuotationRules._();

  static double applyUtility(double cost, double utilityRate) {
    return cost * (1 + utilityRate);
  }

  static double calculateIva(double subtotal, double ivaRate) {
    return subtotal * ivaRate;
  }

  static double calculateTotal({
    required double subtotal,
    required double ivaRate,
    double discountAmount = 0,
  }) {
    final base = subtotal - discountAmount;
    return base + calculateIva(base, ivaRate);
  }
}
