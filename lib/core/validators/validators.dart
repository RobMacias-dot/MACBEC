class Validators {
  const Validators._();

  static String? requiredText(String? value, {String field = 'Campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field es obligatorio';
    }
    return null;
  }

  static String? positiveNumber(String? value, {String field = 'Valor'}) {
    final number = num.tryParse(value?.replaceAll(',', '').trim() ?? '');
    if (number == null) return '$field debe ser numérico';
    if (number <= 0) return '$field debe ser mayor que cero';
    return null;
  }
}
