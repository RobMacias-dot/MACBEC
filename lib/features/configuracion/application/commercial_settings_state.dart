import '../domain/entities/commercial_settings.dart';

class CommercialSettingsState {
  const CommercialSettingsState({
    required this.settings,
    required this.isLoading,
    required this.isSaving,
    this.errorMessage,
  });

  const CommercialSettingsState.initial()
      : settings = const CommercialSettings.defaults(),
        isLoading = false,
        isSaving = false,
        errorMessage = null;

  final CommercialSettings settings;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  CommercialSettingsState copyWith({
    CommercialSettings? settings,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CommercialSettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
