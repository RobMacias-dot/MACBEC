import 'package:flutter_test/flutter_test.dart';
import 'package:macbec_solar_app/features/proyectos/domain/entities/project.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  Project buildProject(String status) {
    return Project(
      id: 'p1',
      clientId: 'c1',
      name: 'Proyecto test',
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('un proyecto finalizado o cancelado ya no cuenta como activo', () {
    expect(buildProject(ProjectStatus.prospecto).isActive, isTrue);
    expect(buildProject(ProjectStatus.cotizando).isActive, isTrue);
    expect(buildProject(ProjectStatus.enInstalacion).isActive, isTrue);
    expect(buildProject(ProjectStatus.finalizado).isActive, isFalse);
    expect(buildProject(ProjectStatus.cancelado).isActive, isFalse);
  });

  test('ProjectStatus.label traduce cada estado conocido', () {
    for (final status in ProjectStatus.values) {
      expect(ProjectStatus.label(status), isNot(equals(status)));
    }
  });

  test('InstallationType.label traduce cada tipo conocido', () {
    for (final type in InstallationType.values) {
      expect(InstallationType.label(type), isNot(equals(type)));
    }
  });
}
