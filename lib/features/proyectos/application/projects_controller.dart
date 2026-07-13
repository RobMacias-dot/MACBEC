import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/database_provider.dart';
import '../data/project_repository.dart';
import '../domain/entities/project.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(appDatabaseProvider));
});

final projectsControllerProvider = FutureProvider<List<Project>>((ref) async {
  return ref.watch(projectRepositoryProvider).getAllActive();
});

final projectByIdProvider =
    FutureProvider.family<Project?, String>((ref, projectId) async {
  return ref.watch(projectRepositoryProvider).getById(projectId);
});

final projectsByClientProvider =
    FutureProvider.family<List<Project>, String>((ref, clientId) async {
  return ref.watch(projectRepositoryProvider).getByClientId(clientId);
});

final projectStatusHistoryProvider =
    FutureProvider.family<List<ProjectStatusHistoryEntry>, String>(
  (ref, projectId) async {
    return ref.watch(projectRepositoryProvider).getStatusHistory(projectId);
  },
);
