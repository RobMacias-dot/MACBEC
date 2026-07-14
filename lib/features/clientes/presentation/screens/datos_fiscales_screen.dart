import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_scaffold.dart';
import '../../data/client_fiscal_repository.dart';
import '../../domain/entities/client_fiscal_profile.dart';
import '../../domain/sat_catalogs.dart';

class DatosFiscalesScreen extends ConsumerStatefulWidget {
  const DatosFiscalesScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<DatosFiscalesScreen> createState() =>
      _DatosFiscalesScreenState();
}

class _DatosFiscalesScreenState extends ConsumerState<DatosFiscalesScreen> {
  final _rfcController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _invoiceEmailController = TextEditingController();

  String? _fiscalRegime;
  String? _cfdiUse;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _rfcController.dispose();
    _legalNameController.dispose();
    _zipCodeController.dispose();
    _invoiceEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync =
        ref.watch(clientFiscalProfileProvider(widget.clientId));

    return AppScaffold(
      title: 'Datos fiscales',
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (profile) {
          _ensureInitialized(profile);

          return ListView(
            children: [
              TextField(
                controller: _rfcController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'RFC',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _legalNameController,
                decoration: const InputDecoration(
                  labelText: 'Razón social',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _fiscalRegime,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Régimen fiscal',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                items: [
                  for (final entry in SatCatalogs.regimenesFiscales.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        '${entry.key} - ${entry.value}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _fiscalRegime = value),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _zipCodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'CP fiscal',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _cfdiUse,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Uso CFDI',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
                items: [
                  for (final entry in SatCatalogs.usosCfdi.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        '${entry.key} - ${entry.value}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _cfdiUse = value),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _invoiceEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo para factura',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar datos fiscales',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _ensureInitialized(ClientFiscalProfile? profile) {
    if (_initialized) return;
    _initialized = true;

    _rfcController.text = profile?.rfc ?? '';
    _legalNameController.text = profile?.legalName ?? '';
    _zipCodeController.text = profile?.fiscalZipCode ?? '';
    _invoiceEmailController.text = profile?.invoiceEmail ?? '';
    _fiscalRegime = profile?.fiscalRegime;
    _cfdiUse = profile?.cfdiUse;
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(clientFiscalRepositoryProvider).upsert(
            clientId: widget.clientId,
            input: SaveClientFiscalProfileInput(
              rfc: _rfcController.text,
              legalName: _legalNameController.text,
              fiscalRegime: _fiscalRegime,
              fiscalZipCode: _zipCodeController.text,
              cfdiUse: _cfdiUse,
              invoiceEmail: _invoiceEmailController.text,
            ),
          );

      ref.invalidate(clientFiscalProfileProvider(widget.clientId));

      if (!mounted) return;

      context.pop();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
