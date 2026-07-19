import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../data/local/database/app_database.dart';
import '../../data/mec_repository.dart';

class MecProductManagerScreen extends StatefulWidget {
  const MecProductManagerScreen({super.key});

  @override
  State<MecProductManagerScreen> createState() =>
      _MecProductManagerScreenState();
}

class _MecProductManagerScreenState extends State<MecProductManagerScreen> {
  final _database = AppDatabase();
  late final MecRepository _repository = MecRepository(_database);
  String _query = '';

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Administrador de Productos MEC')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'La creación técnica se realiza desde el flujo de ficha técnica.'))),
          icon: const Icon(Icons.add),
          label: const Text('Crear producto'),
        ),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    labelText: 'Buscar marca, modelo, código, SKU o proveedor'),
                onChanged: (value) => setState(() => _query = value),
              )),
          Expanded(
              child: FutureBuilder<List<MecProductSummary>>(
            future: _repository.listProducts(query: _query),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final products = snapshot.data!;
              if (products.isEmpty)
                return const Center(
                    child: Text('No se encontraron productos.'));
              return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final item = products[index];
                    return FutureBuilder<List<CommercialOfferWithSupplier>>(
                      future:
                          _repository.listCommercialOffers(item.type, item.id),
                      builder: (context, offers) {
                        final active = offers.data
                                ?.where((offer) => offer.offer.isActive)
                                .toList() ??
                            [];
                        final price = active
                            .where((offer) => offer.offer.price != null)
                            .map((offer) => offer.offer)
                            .firstOrNull;
                        return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            child: ListTile(
                              title: Text('${item.brand} ${item.model}'),
                              subtitle: Text(
                                  '${item.type == 'panel' ? 'Panel' : 'Inversor'} · ${item.powerLabel} · ${active.length} proveedor(es)${price == null ? '' : ' · ${price.currency} ${price.price!.toStringAsFixed(2)}'}'),
                              leading: Icon(item.type == 'panel'
                                  ? Icons.solar_power_outlined
                                  : Icons.electric_bolt_outlined),
                              trailing: Wrap(spacing: 4, children: [
                                Chip(
                                    label: Text(
                                        item.active ? 'Activo' : 'Inactivo')),
                                const Chip(label: Text('Apto: revisar'))
                              ]),
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => MecProductEditorScreen(
                                          product: item))),
                            ));
                      },
                    );
                  });
            },
          )),
        ]),
      );
}

class MecProductEditorScreen extends StatefulWidget {
  const MecProductEditorScreen({super.key, required this.product});
  final MecProductSummary product;
  @override
  State<MecProductEditorScreen> createState() => _MecProductEditorScreenState();
}

class _MecProductEditorScreenState extends State<MecProductEditorScreen> {
  final _database = AppDatabase();
  late final _repository = MecRepository(_database);
  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
            title: Text('${widget.product.brand} ${widget.product.model}'),
            bottom: const TabBar(tabs: [
              Tab(text: 'General'),
              Tab(text: 'Proveedores y precios'),
              Tab(text: 'Información técnica')
            ])),
        body: TabBarView(children: [
          _GeneralTab(product: widget.product, repository: _repository),
          _OffersTab(product: widget.product, repository: _repository),
          _TechnicalTab(product: widget.product, database: _database)
        ]),
      ));
}

class _GeneralTab extends StatefulWidget {
  const _GeneralTab({required this.product, required this.repository});
  final MecProductSummary product;
  final MecRepository repository;
  @override
  State<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends State<_GeneralTab> {
  late final brand = TextEditingController(text: widget.product.brand),
      model = TextEditingController(text: widget.product.model),
      description = TextEditingController(text: widget.product.description);
  bool active = true;
  @override
  void dispose() {
    brand.dispose();
    model.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
            controller: brand,
            decoration: const InputDecoration(labelText: 'Marca')),
        TextField(
            controller: model,
            decoration: const InputDecoration(labelText: 'Modelo')),
        TextField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Descripción corta')),
        const SizedBox(height: 8),
        Text('Código interno MEC: ${widget.product.id}'),
        SwitchListTile(
            value: active,
            onChanged: (v) => setState(() => active = v),
            title: const Text('Activo')),
        const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text(
                'Estado técnico y aptitud se determinan por la revisión vigente.')),
        FilledButton(
            onPressed: () async {
              if (brand.text != widget.product.brand ||
                  model.text != widget.product.model) {
                final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                            title: const Text('Confirmar identidad'),
                            content: const Text(
                                'Cambiar la marca o el modelo puede representar un producto técnico diferente. Verifica que solo corriges el nombre.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Continuar'))
                            ]));
                if (ok != true) return;
              }
              await widget.repository.updateProductGeneral(widget.product,
                  brand: brand.text,
                  model: model.text,
                  description: description.text,
                  active: active);
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Datos generales guardados.')));
            },
            child: const Text('Guardar')),
      ]);
}

class _OffersTab extends StatefulWidget {
  const _OffersTab({required this.product, required this.repository});
  final MecProductSummary product;
  final MecRepository repository;
  @override
  State<_OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends State<_OffersTab> {
  late Future<List<CommercialOfferWithSupplier>> _offers = _load();
  Future<List<CommercialOfferWithSupplier>> _load() => widget.repository
      .listCommercialOffers(widget.product.type, widget.product.id);
  Future<void> _edit([CommercialOffer? offer]) async {
    final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _OfferForm(
            product: widget.product,
            repository: widget.repository,
            offer: offer));
    if (saved == true) setState(() => _offers = _load());
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<CommercialOfferWithSupplier>>(
          future: _offers,
          builder: (context, snapshot) {
            final offers = snapshot.data ?? [];
            return ListView(padding: const EdgeInsets.all(16), children: [
              FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar proveedor o precio')),
              const SizedBox(height: 12),
              if (!snapshot.hasData)
                const Center(child: CircularProgressIndicator()),
              ...offers.map((item) => Card(
                  child: ListTile(
                      title: Text(item.supplierName),
                      subtitle: Text(
                          'SKU: ${item.offer.supplierSku ?? '—'}\n${item.offer.currency} ${item.offer.price?.toStringAsFixed(2) ?? 'Sin precio'} · ${item.offer.available ? 'Disponible' : 'No disponible'} · ${item.offer.priceDate?.toIso8601String().split('T').first ?? 'Sin fecha'}'),
                      isThreeLine: true,
                      trailing: Wrap(direction: Axis.vertical, children: [
                        IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(item.offer)),
                        IconButton(
                            icon: Icon(item.offer.isActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline),
                            onPressed: () async {
                              await widget.repository.setCommercialOfferActive(
                                item.offer.id,
                                !item.offer.isActive,
                              );
                              setState(() => _offers = _load());
                            })
                      ])))),
            ]);
          });
}

class _OfferForm extends StatefulWidget {
  const _OfferForm(
      {required this.product, required this.repository, this.offer});
  final MecProductSummary product;
  final MecRepository repository;
  final CommercialOffer? offer;
  @override
  State<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<_OfferForm> {
  late final supplier =
          TextEditingController(text: widget.offer?.supplierName ?? ''),
      sku = TextEditingController(text: widget.offer?.supplierSku ?? ''),
      price =
          TextEditingController(text: widget.offer?.price?.toString() ?? ''),
      notes = TextEditingController(text: widget.offer?.notes ?? '');
  bool available = true, vat = false;
  String currency = 'MXN';
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.offer == null ? 'Nueva oferta comercial' : 'Editar oferta',
            style: Theme.of(context).textTheme.titleLarge),
        TextField(
            controller: supplier,
            decoration: const InputDecoration(labelText: 'Proveedor')),
        TextField(
            controller: sku,
            decoration:
                const InputDecoration(labelText: 'Código o SKU del proveedor')),
        TextField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Precio')),
        DropdownButtonFormField(
            value: currency,
            items: const ['MXN', 'USD']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => currency = v!)),
        SwitchListTile(
            value: available,
            onChanged: (v) => setState(() => available = v),
            title: const Text('Disponible')),
        SwitchListTile(
            value: vat,
            onChanged: (v) => setState(() => vat = v),
            title: const Text('IVA incluido')),
        TextField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'Notas comerciales')),
        FilledButton(
            onPressed: () async {
              try {
                await widget.repository.saveCommercialOffer(
                    CommercialOffersCompanion(
                        id: widget.offer == null
                            ? const Value.absent()
                            : Value(widget.offer!.id),
                        productType: Value(widget.product.type),
                        productId: Value(widget.product.id),
                        supplierName: Value(supplier.text),
                        supplierSku: Value(sku.text),
                        price: Value(double.tryParse(price.text)),
                        currency: Value(currency),
                        available: Value(available),
                        vatIncluded: Value(vat),
                        priceDate: Value(DateTime.now()),
                        notes: Value(notes.text)));
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Guardar'))
      ])));
}

class _TechnicalTab extends StatelessWidget {
  const _TechnicalTab({required this.product, required this.database});
  final MecProductSummary product;
  final AppDatabase database;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Información técnica (solo lectura)'),
            subtitle: Text(
                'Los valores técnicos solo cambian mediante una nueva revisión.')),
        if (product.type == 'panel')
          FutureBuilder<Panel?>(
              future: (database.select(database.panels)
                    ..where((r) => r.id.equals(product.id)))
                  .getSingleOrNull(),
              builder: (c, s) {
                final p = s.data;
                if (p == null) return const SizedBox();
                return Card(
                    child: Column(children: [
                  _row('Potencia máxima', '${p.powerWatts} W'),
                  _row('Voc', '${p.voc ?? '—'} V'),
                  _row('Isc', '${p.isc ?? '—'} A'),
                  _row('Dimensiones',
                      '${p.lengthMm ?? '—'} × ${p.widthMm ?? '—'} mm')
                ]));
              }),
        if (product.type == 'inverter')
          FutureBuilder<Inverter?>(
              future: (database.select(database.inverters)
                    ..where((r) => r.id.equals(product.id)))
                  .getSingleOrNull(),
              builder: (c, s) {
                final i = s.data;
                if (i == null) return const SizedBox();
                return Card(
                    child: Column(children: [
                  _row('Potencia nominal', '${i.nominalPowerWatts} W'),
                  _row('Potencia FV máxima', '${i.maxPvPowerWatts ?? '—'} W'),
                  _row('Voltaje DC máximo', '${i.maxDcVoltage ?? '—'} V'),
                  _row('MPPT', '${i.mpptCount ?? '—'}')
                ]));
              }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Dirígete a Fichas técnicas PDF para crear una revisión.'))),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Crear nueva revisión técnica'))
      ]);
}

Widget _row(String label, String value) =>
    ListTile(title: Text(label), trailing: Text(value));
