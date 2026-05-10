import '../domain/entities/company_profile.dart';

class CompanySettingsState {
  const CompanySettingsState({
    required this.profile,
    required this.isLoading,
    required this.isSaving,
    this.errorMessage,
  });

  const CompanySettingsState.initial()
      : profile = const CompanyProfile.empty(),
        isLoading = false,
        isSaving = false,
        errorMessage = null;

  final CompanyProfile profile;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  CompanySettingsState copyWith({
    CompanyProfile? profile,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CompanySettingsState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
