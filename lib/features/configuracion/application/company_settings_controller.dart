import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/company_settings_repository.dart';
import '../domain/entities/company_profile.dart';
import 'company_settings_state.dart';

final companySettingsControllerProvider =
    StateNotifierProvider<CompanySettingsController, CompanySettingsState>(
        (ref) {
  return CompanySettingsController(
    repository: ref.watch(companySettingsRepositoryProvider),
  );
});

class CompanySettingsController extends StateNotifier<CompanySettingsState> {
  CompanySettingsController({
    required CompanySettingsRepository repository,
  })  : _repository = repository,
        super(const CompanySettingsState.initial());

  final CompanySettingsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final profile = await _repository.getCompanyProfile();

      state = state.copyWith(
        profile: profile ?? const CompanyProfile.empty(),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo cargar la configuración de empresa.',
      );
    }
  }

  Future<bool> save({
    required String companyName,
    required String rfc,
    required String phone,
    required String email,
    required String address,
  }) async {
    final normalizedCompanyName = companyName.trim();
    final normalizedRfc = rfc.trim().toUpperCase();
    final normalizedPhone = phone.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedAddress = address.trim();

    if (normalizedCompanyName.isEmpty) {
      state = state.copyWith(
        errorMessage: 'El nombre de la empresa es obligatorio.',
      );
      return false;
    }

    if (normalizedEmail.isNotEmpty && !_isValidEmail(normalizedEmail)) {
      state = state.copyWith(
        errorMessage: 'Ingresa un correo válido para la empresa.',
      );
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
    );

    try {
      final savedProfile = await _repository.saveCompanyProfile(
        CompanyProfile(
          id: state.profile.id,
          companyName: normalizedCompanyName,
          rfc: normalizedRfc,
          phone: normalizedPhone,
          email: normalizedEmail,
          address: normalizedAddress,
        ),
      );

      state = state.copyWith(
        profile: savedProfile,
        isSaving: false,
      );

      return true;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'No se pudo guardar la configuración de empresa.',
      );
      return false;
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }
}
