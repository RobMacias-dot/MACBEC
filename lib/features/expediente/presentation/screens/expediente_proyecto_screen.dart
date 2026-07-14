import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../proyectos/application/projects_controller.dart';
import '../../data/documents_repository.dart';
import '../../domain/entities/document_record.dart';

class ExpedienteProyectoScreen extends ConsumerWidget {
  const ExpedienteProyectoScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectByIdProvider(projectId));
    final documentsAsync = ref.watch(documentsByProjectProvider(projectId));

    return AppScaffold(
      title: 'Expediente del proyecto',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () =>
              ref.invalidate(documentsByProjectProvider(projectId)),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: projectAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          title: 'No se pudo cargar el proyecto',
          message: error.toString(),
          icon: Icons.error_outline,
        ),
        data: (project) {
          if (project == null) {
            return const EmptyState(
              title: 'Proyecto no encontrado',
              message: 'Puede que haya sido eliminado.',
              icon: Icons.folder_off_outlined,
            );
          }

          return ListView(
            children: [
              SectionCard(
                title: project.name,
                child: const Text(
                  'Documentos generados a lo largo del flujo de este '
                  'proyecto: recibo CFE, cotización, propuesta técnica, '
                  'estructura, contrato firmado y pre-factura.',
                ),
              ),
              const SizedBox(height: 16),
              documentsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) => Text('Error: $error'),
                data: (documents) {
                  if (documents.isEmpty) {
                    return const EmptyState(
                      title: 'Sin documentos todavía',
                      message:
                          'Los documentos que generes en las cotizaciones de '
                          'este proyecto aparecerán aquí.',
                      icon: Icons.folder_open_outlined,
                    );
                  }

                  return Column(
                    children: documents
                        .map(
                          (document) => _DocumentTile(document: document),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final DocumentRecord document;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
      child: ListTile(
        leading: Icon(_iconFor(document.documentType)),
        title: Text(document.typeLabel),
        subtitle: Text(_formatDate(document.createdAt)),
        trailing: IconButton(
          tooltip: 'Compartir',
          icon: const Icon(Icons.share_outlined),
          onPressed: () => _share(context, document),
        ),
      ),
    );
  }

  IconData _iconFor(String documentType) {
    switch (documentType) {
      case DocumentTypes.cfeReceipt:
        return Icons.receipt_long_outlined;
      case DocumentTypes.quotationPdf:
      case DocumentTypes.technicalProposalPdf:
      case DocumentTypes.structuralPdf:
      case DocumentTypes.contractPdf:
      case DocumentTypes.preInvoicePdf:
        return Icons.picture_as_pdf_outlined;
      case DocumentTypes.clientSignature:
      case DocumentTypes.providerSignature:
        return Icons.draw_outlined;
      case DocumentTypes.photo:
        return Icons.photo_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _share(BuildContext context, DocumentRecord document) async {
    try {
      await Share.shareXFiles([XFile(document.localPath)]);
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir el archivo: $error')),
      );
    }
  }
}
