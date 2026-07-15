import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/nominatim_client.dart';

/// Campo de dirección con autocomplete vía Nominatim/OpenStreetMap y una
/// vista previa de mapa opcional. No usa Google Places (sin costo, sin API
/// key) - ver Fase 1.7 del plan de mejoras.
class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.labelText = 'Dirección',
    this.helperText,
    this.validator,
    this.enabled = true,
    this.showMap = true,
    this.onLocationSelected,
  });

  final TextEditingController controller;
  final String labelText;
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool showMap;
  final ValueChanged<LatLng>? onLocationSelected;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final _nominatimClient = NominatimClient();
  Timer? _debounce;
  List<NominatimSuggestion> _suggestions = const [];
  bool _isSearching = false;
  LatLng? _selectedPoint;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();

    if (_selectedPoint != null) {
      setState(() => _selectedPoint = null);
    }

    if (value.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 600), () {
      _search(value);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);

    try {
      final results = await _nominatimClient.search(query);
      if (!mounted) return;
      setState(() => _suggestions = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggestions = const []);
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _selectSuggestion(NominatimSuggestion suggestion) {
    widget.controller.text = suggestion.displayName;
    final point = LatLng(suggestion.latitude, suggestion.longitude);

    setState(() {
      _suggestions = const [];
      _selectedPoint = point;
    });

    widget.onLocationSelected?.call(point);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          onChanged: _onChanged,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: widget.labelText,
            helperText: widget.helperText,
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          validator: widget.validator,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final suggestion in _suggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(
                      suggestion.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectSuggestion(suggestion),
                  ),
              ],
            ),
          ),
        if (widget.showMap && _selectedPoint != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _selectedPoint!,
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.macbec.solar_app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedPoint!,
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.location_pin,
                          color: theme.colorScheme.error,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
