import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/database_provider.dart';
import '../data/client_repository.dart';
import '../domain/entities/client.dart' as client_entity;

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(appDatabaseProvider));
});

final clientsControllerProvider =
    FutureProvider<List<client_entity.Client>>((ref) async {
  return ref.watch(clientRepositoryProvider).getAll();
});

final clientByIdProvider =
    FutureProvider.family<client_entity.Client?, String>((ref, clientId) async {
  return ref.watch(clientRepositoryProvider).getById(clientId);
});
