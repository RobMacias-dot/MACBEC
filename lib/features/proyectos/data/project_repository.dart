import 'package:drift/drift.dart';

import '../../../data/local/database/app_database.dart';
import '../domain/entities/project.dart' as project_entity;

class ProjectRepository {
  ProjectRepository(this._database);

  final AppDatabase _database;

  Future<List<project_entity.Project>> getAllActive() async {
    final query = _database.select(_database.projects)
      ..where((project) => project.isDeleted.equals(false))
      ..orderBy([(project) => OrderingTerm.desc(project.updatedAt)]);

    final rows = await query.get();

    return rows.map(_mapRowToEntity).toList();
  }

  Future<List<project_entity.Project>> getByClientId(String clientId) async {
    final query = _database.select(_database.projects)
      ..where(
        (project) =>
            project.clientId.equals(clientId) &
            project.isDeleted.equals(false),
      )
      ..orderBy([(project) => OrderingTerm.desc(project.updatedAt)]);

    final rows = await query.get();

    return rows.map(_mapRowToEntity).toList();
  }

  Future<project_entity.Project?> getById(String projectId) async {
    final query = _database.select(_database.projects)
      ..where(
        (project) =>
            project.id.equals(projectId) & project.isDeleted.equals(false),
      );

    final row = await query.getSingleOrNull();

    if (row == null) return null;

    return _mapRowToEntity(row);
  }

  Future<String> create(project_entity.SaveProjectInput input) async {
    final now = DateTime.now();

    final row = await _database.into(_database.projects).insertReturning(
          ProjectsCompanion.insert(
            clientId: input.clientId,
            name: input.name.trim(),
            installationType: Value(
              _cleanNullableText(input.installationType),
            ),
            serviceAddress: Value(_cleanNullableText(input.serviceAddress)),
            state: Value(_cleanNullableText(input.state)),
            municipality: Value(_cleanNullableText(input.municipality)),
            notes: Value(_cleanNullableText(input.notes)),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return row.id;
  }

  Future<void> update({
    required String projectId,
    required project_entity.SaveProjectInput input,
  }) async {
    final now = DateTime.now();

    await (_database.update(_database.projects)
          ..where((project) => project.id.equals(projectId)))
        .write(
      ProjectsCompanion(
        clientId: Value(input.clientId),
        name: Value(input.name.trim()),
        installationType: Value(_cleanNullableText(input.installationType)),
        serviceAddress: Value(_cleanNullableText(input.serviceAddress)),
        state: Value(_cleanNullableText(input.state)),
        municipality: Value(_cleanNullableText(input.municipality)),
        notes: Value(_cleanNullableText(input.notes)),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> changeStatus({
    required String projectId,
    required String newStatus,
    String? notes,
  }) async {
    final now = DateTime.now();

    await _database.transaction(() async {
      final project = await (_database.select(_database.projects)
            ..where((table) => table.id.equals(projectId)))
          .getSingleOrNull();

      if (project == null) {
        throw StateError('El proyecto no existe.');
      }

      await (_database.update(_database.projects)
            ..where((table) => table.id.equals(projectId)))
          .write(
        ProjectsCompanion(
          status: Value(newStatus),
          updatedAt: Value(now),
        ),
      );

      await _database.into(_database.projectStatusHistory).insert(
            ProjectStatusHistoryCompanion.insert(
              projectId: projectId,
              previousStatus: Value(project.status),
              newStatus: newStatus,
              notes: Value(_cleanNullableText(notes)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    });
  }

  Future<List<project_entity.ProjectStatusHistoryEntry>> getStatusHistory(
    String projectId,
  ) async {
    final query = _database.select(_database.projectStatusHistory)
      ..where(
        (table) =>
            table.projectId.equals(projectId) & table.isDeleted.equals(false),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

    final rows = await query.get();

    return rows
        .map(
          (row) => project_entity.ProjectStatusHistoryEntry(
            id: row.id,
            projectId: row.projectId,
            previousStatus: row.previousStatus,
            newStatus: row.newStatus,
            notes: row.notes,
            createdAt: row.createdAt,
          ),
        )
        .toList();
  }

  project_entity.Project _mapRowToEntity(Project row) {
    return project_entity.Project(
      id: row.id,
      clientId: row.clientId,
      name: row.name,
      status: row.status,
      installationType: row.installationType,
      serviceAddress: row.serviceAddress,
      state: row.state,
      municipality: row.municipality,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String? _cleanNullableText(String? value) {
    final cleanValue = value?.trim() ?? '';
    return cleanValue.isEmpty ? null : cleanValue;
  }
}
