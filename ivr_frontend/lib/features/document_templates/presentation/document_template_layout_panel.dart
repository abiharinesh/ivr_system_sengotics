import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../models/document_template_config.dart';

class DocumentTemplateLayoutPanel extends StatelessWidget {
  const DocumentTemplateLayoutPanel({
    super.key,
    required this.templateId,
    required this.entry,
    required this.draft,
    required this.onDraftChanged,
    this.showPanchayatHint = false,
    this.showPreviewPanchayatId = false,
    this.onPreviewPanchayatIdChanged,
  });

  final String templateId;
  final TemplateSettingsEntry? entry;
  final DocumentTemplateConfig draft;
  final ValueChanged<DocumentTemplateConfig> onDraftChanged;
  final bool showPanchayatHint;
  final bool showPreviewPanchayatId;
  final ValueChanged<int?>? onPreviewPanchayatIdChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry != null) ...[
            Text(
              '${entry!.labelEn}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (showPanchayatHint && entry!.hasGlobal)
                    Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Empty fields inherit platform defaults.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            const SizedBox(height: 12),
          ],
          _sectionTitle('Page'),
          _slider(
            label: 'Padding (px)',
            value: (draft.page?.paddingPx ?? 24).toDouble(),
            min: 0,
            max: 80,
            onChanged:
                (v) => onDraftChanged(
                  draft.copyWith(
                    page: PageConfig(
                      paddingPx: v.round(),
                      maxWidthPx: draft.page?.maxWidthPx ?? 720,
                    ),
                  ),
                ),
          ),
          _slider(
            label: 'Max width (px)',
            value: (draft.page?.maxWidthPx ?? 720).toDouble(),
            min: 400,
            max: 1200,
            onChanged:
                (v) => onDraftChanged(
                  draft.copyWith(
                    page: PageConfig(
                      paddingPx: draft.page?.paddingPx ?? 24,
                      maxWidthPx: v.round(),
                    ),
                  ),
                ),
          ),
          _sectionTitle('Alignment'),
          _alignDropdown(
            'Header',
            draft.header?.align ?? 'center',
            kTextAlignOptions,
            (a) =>
                onDraftChanged(draft.copyWith(header: AlignConfig(align: a))),
          ),
          _alignDropdown(
            'Body',
            draft.body?.align ?? 'left',
            kTextAlignOptions,
            (a) => onDraftChanged(draft.copyWith(body: AlignConfig(align: a))),
          ),
          _alignDropdown(
            'Table headers',
            draft.table?.headerAlign ?? 'left',
            kTextAlignOptions,
            (a) => onDraftChanged(
              draft.copyWith(
                table: TableConfig(
                  headerAlign: a,
                  bodyAlign: draft.table?.bodyAlign,
                  numberAlign: draft.table?.numberAlign,
                ),
              ),
            ),
          ),
          _alignDropdown(
            'Table cells',
            draft.table?.bodyAlign ?? 'left',
            kTextAlignOptions,
            (a) => onDraftChanged(
              draft.copyWith(
                table: TableConfig(
                  headerAlign: draft.table?.headerAlign,
                  bodyAlign: a,
                  numberAlign: draft.table?.numberAlign,
                ),
              ),
            ),
          ),
          _alignDropdown(
            'Amount columns',
            draft.table?.numberAlign ?? 'right',
            const ['left', 'right'],
            (a) => onDraftChanged(
              draft.copyWith(
                table: TableConfig(
                  headerAlign: draft.table?.headerAlign,
                  bodyAlign: draft.table?.bodyAlign,
                  numberAlign: a,
                ),
              ),
            ),
          ),
          _alignDropdown(
            'Signatures',
            draft.signatures?.align ?? 'center',
            kSignatureAlignOptions,
            (a) => onDraftChanged(
              draft.copyWith(signatures: AlignConfig(align: a)),
            ),
          ),
          _sectionTitle('Typography'),
          _slider(
            label: 'Base font (pt)',
            value: (draft.typography?.baseFontPt ?? 10).toDouble(),
            min: 8,
            max: 16,
            onChanged:
                (v) => onDraftChanged(
                  draft.copyWith(
                    typography: TypographyConfig(
                      baseFontPt: v.round(),
                      titleFontPt: draft.typography?.titleFontPt ?? 18,
                    ),
                  ),
                ),
          ),
          _slider(
            label: 'Title font (pt)',
            value: (draft.typography?.titleFontPt ?? 18).toDouble(),
            min: 12,
            max: 28,
            onChanged:
                (v) => onDraftChanged(
                  draft.copyWith(
                    typography: TypographyConfig(
                      baseFontPt: draft.typography?.baseFontPt ?? 10,
                      titleFontPt: v.round(),
                    ),
                  ),
                ),
          ),
          _sectionTitle('Footer'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Show generated footer',
              style: TextStyle(fontSize: 13),
            ),
            value: draft.branding?.showGeneratedFooter ?? true,
            onChanged:
                (v) => onDraftChanged(
                  draft.copyWith(
                    branding: BrandingConfig(
                      showGeneratedFooter: v,
                      customFooterTextTa: draft.branding?.customFooterTextTa,
                      customFooterTextEn: draft.branding?.customFooterTextEn,
                    ),
                  ),
                ),
          ),
          if (showPreviewPanchayatId) ...[
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Preview panchayat ID',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged:
                  (v) => onPreviewPanchayatIdChanged?.call(int.tryParse(v)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.round()}', style: const TextStyle(fontSize: 12)),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _alignDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : options.first,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items:
            options
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}