class ProjectStatus {
  const ProjectStatus._();

  static const prospecto = 'prospecto';
  static const cotizando = 'cotizando';
  static const cotizado = 'cotizado';
  static const contratado = 'contratado';
  static const enInstalacion = 'en_instalacion';
  static const finalizado = 'finalizado';
  static const cancelado = 'cancelado';

  static const values = [
    prospecto,
    cotizando,
    cotizado,
    contratado,
    enInstalacion,
    finalizado,
    cancelado,
  ];

  static String label(String status) {
    switch (status) {
      case prospecto:
        return 'Prospecto';
      case cotizando:
        return 'Cotizando';
      case cotizado:
        return 'Cotizado';
      case contratado:
        return 'Contratado';
      case enInstalacion:
        return 'En instalación';
      case finalizado:
        return 'Finalizado';
      case cancelado:
        return 'Cancelado';
      default:
        return status;
    }
  }
}

/// Tipos de instalación fotovoltaica que maneja MacBec (ver documentos
/// funcionales: SFVI, SF Isla, SF Híbrido, SF de bombeo).
class InstallationType {
  const InstallationType._();

  static const sfvi = 'sfvi';
  static const isla = 'isla';
  static const hibrido = 'hibrido';
  static const bombeo = 'bombeo';

  static const values = [sfvi, isla, hibrido, bombeo];

  static String label(String type) {
    switch (type) {
      case sfvi:
        return 'SFVI (Interconectado)';
      case isla:
        return 'SF Isla';
      case hibrido:
        return 'SF Híbrido';
      case bombeo:
        return 'SF de bombeo';
      default:
        return type;
    }
  }
}

class Project {
  const Project({
    required this.id,
    required this.clientId,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.installationType,
    this.serviceAddress,
    this.state,
    this.municipality,
    this.notes,
  });

  final String id;
  final String clientId;
  final String name;
  final String status;
  final String? installationType;
  final String? serviceAddress;
  final String? state;
  final String? municipality;
  final String? notes;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive =>
      status != ProjectStatus.cancelado && status != ProjectStatus.finalizado;
}

class SaveProjectInput {
  const SaveProjectInput({
    required this.clientId,
    required this.name,
    this.installationType,
    this.serviceAddress,
    this.state,
    this.municipality,
    this.notes,
  });

  final String clientId;
  final String name;
  final String? installationType;
  final String? serviceAddress;
  final String? state;
  final String? municipality;
  final String? notes;
}

class ProjectStatusHistoryEntry {
  const ProjectStatusHistoryEntry({
    required this.id,
    required this.projectId,
    required this.newStatus,
    required this.createdAt,
    this.previousStatus,
    this.notes,
  });

  final String id;
  final String projectId;
  final String? previousStatus;
  final String newStatus;
  final String? notes;
  final DateTime createdAt;
}
