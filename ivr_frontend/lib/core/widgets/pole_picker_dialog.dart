import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../models/pole_model.dart';
import 'map_overview.dart';

Future<PoleModel?> showPolePickerDialog({
  required BuildContext context,
  required List<PoleModel> poles,
  String title = 'Select Pole',
  String confirmLabel = 'Use this Pole',
}) {
  return showDialog<PoleModel>(
    context: context,
    builder:
        (ctx) => _PolePickerDialog(
          poles: poles,
          title: title,
          confirmLabel: confirmLabel,
        ),
  );
}

class _PolePickerDialog extends StatefulWidget {
  final List<PoleModel> poles;
  final String title;
  final String confirmLabel;

  const _PolePickerDialog({
    required this.poles,
    required this.title,
    required this.confirmLabel,
  });

  @override
  State<_PolePickerDialog> createState() => _PolePickerDialogState();
}

class _PolePickerDialogState extends State<_PolePickerDialog> {
  PoleModel? _selectedPole;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: SizedBox(
        width: 920,
        height: 620,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style:       TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: MapOverview(
                        poles: widget.poles,
                        height: 560,
                        onPoleTap: (pole) => setState(() => _selectedPole = pole),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.stroke),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            widget.poles.isEmpty
                                ? const Center(child: Text('No poles found'))
                                : ListView.separated(
                                  itemCount: widget.poles.length,
                                  separatorBuilder:
                                      (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final pole = widget.poles[index];
                                    final selected = _selectedPole?.id == pole.id;
                                    return ListTile(
                                      selected: selected,
                                      selectedTileColor: AppTheme.bgSurface,
                                      title: Text(
                                        pole.poleNumber?.isNotEmpty == true
                                            ? pole.poleNumber!
                                            : 'Pole #${pole.id}',
                                      ),
                                      subtitle: Text(
                                        'ID ${pole.id}'
                                        '${pole.keypadId == null ? '' : ' · Keypad ${pole.keypadId}'}',
                                      ),
                                      onTap: () => setState(() => _selectedPole = pole),
                                    );
                                  },
                                ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedPole == null
                          ? 'Select a pole from map or list'
                          : 'Selected: ${_selectedPole!.poleNumber ?? '#${_selectedPole!.id}'}',
                      style:       TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed:
                        _selectedPole == null
                            ? null
                            : () => Navigator.of(context).pop(_selectedPole),
                    child: Text(widget.confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}