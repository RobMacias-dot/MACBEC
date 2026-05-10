import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/commercial_settings_repository.dart';
import '../domain/entities/commercial_settings.dart';
import 'commercial_settings_state.dart';

final commercialSettingsControllerProvider = StateNotifierProvider<
    CommercialSettingsController, CommercialSettingsState>((ref) {
  return CommercialSettingsController(
    repository: ref.watch(commercialSettingsRepositoryProvider),
  );
});

class CommercialSettingsController
    extends StateNotifier<CommercialSettingsState> {
  CommercialSettingsController({
    required CommercialSettingsRepository repository,
  })  : _repository = repository,
        super(const CommercialSettingsState.initial());

  final CommercialSettingsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final settings = await _repository.getCommercialSettings();

      state = state.copyWith(
        settings: settings,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudieron cargar los parámetros comerciales.',
      );
    }
  }

  Future<bool> save({
    required String ivaRatePercent,
    required String generalUtilityRatePercent,
    required String currency,
    required String defaultQuotationValidityDays,
    required String quotationLegalNote,
    required String warrantyNote,
  }) async {
    final parsedIvaRate = _parseDouble(ivaRatePercent);
    final parsedUtilityRate = _parseDouble(generalUtilityRatePercent);
    final parsedValidityDays = int.tryParse(
      defaultQuotationValidityDays.trim(),
    );
    final normalizedCurrency = currency.trim().toUpperCase();
    final normalizedQuotationLegalNote = quotationLegalNote.trim();
    final normalizedWarrantyNote = warrantyNote.trim();

    if (parsedIvaRate == null) {
      return _fail('Ingresa un IVA válido.');
    }

    if (parsedIvaRate < 0 || parsedIvaRate > 100) {
      return _fail('El IVA debe estar entre 0 y 100%.');
    }

    if (parsedUtilityRate == null) {
      return _fail('Ingresa una utilidad base válida.');
    }

    if (parsedUtilityRate < 0 || parsedUtilityRate > 300) {
      return _fail('La utilidad base debe estar entre 0 y 300%.');
    }

    if (normalizedCurrency.isEmpty) {
      return _fail('La moneda es obligatoria.');
    }

    if (!RegExp(r'^[A-Z]{3}$').hasMatch(normalizedCurrency)) {
      return _fail('La moneda debe usar 3 letras, por ejemplo MXN o USD.');
    }

    if (parsedValidityDays == null) {
      return _fail('Ingresa una vigencia válida en días.');
    }

    if (parsedValidityDays < 1 || parsedValidityDays > 365) {
      return _fail('La vigencia debe estar entre 1 y 365 días.');
    }

    if (normalizedQuotationLegalNote.isEmpty) {
      return _fail('El texto legal de cotización es obligatorio.');
    }

    if (normalizedWarrantyNote.isEmpty) {
      return _fail('El texto de garantía es obligatorio.');
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
    );

    try {
      final savedSettings = await _repository.saveCommercialSettings(
        CommercialSettings(
          ivaRatePercent: parsedIvaRate,
          generalUtilityRatePercent: parsedUtilityRate,
          currency: normalizedCurrency,
          defaultQuotationValidityDays: parsedValidityDays,
          quotationLegalNote: normalizedQuotationLegalNote,
          warrantyNote: normalizedWarrantyNote,
        ),
      );

      state = state.copyWith(
        settings: savedSettings,
        isSaving: false,
      );

      return true;
    } catch (_) {
      return _fail(
        'No se pudieron guardar los parámetros comerciales.',
        isSaving: false,
      );
    }
  }

  bool _fail(String message, {bool isSaving = false}) {
    state = state.copyWith(
      isSaving: isSaving,
      errorMessage: message,
    );

    return false;
  }

  double? _parseDouble(String value) {
    final normalizedValue = value.trim().replaceAll(',', '.');

    if (normalizedValue.isEmpty) {
      return null;
    }

    return double.tryParse(normalizedValue);
  }
}
