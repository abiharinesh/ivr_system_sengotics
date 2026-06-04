class DocumentTemplateConfig {
  final PageConfig? page;
  final AlignConfig? header;
  final AlignConfig? body;
  final TableConfig? table;
  final AlignConfig? signatures;
  final TypographyConfig? typography;
  final BrandingConfig? branding;
  final Map<String, dynamic>? defaults;

  const DocumentTemplateConfig({
    this.page,
    this.header,
    this.body,
    this.table,
    this.signatures,
    this.typography,
    this.branding,
    this.defaults,
  });

  factory DocumentTemplateConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DocumentTemplateConfig();
    return DocumentTemplateConfig(
      page: json['page'] is Map ? PageConfig.fromJson(json['page'] as Map) : null,
      header: json['header'] is Map ? AlignConfig.fromJson(json['header'] as Map) : null,
      body: json['body'] is Map ? AlignConfig.fromJson(json['body'] as Map) : null,
      table: json['table'] is Map ? TableConfig.fromJson(json['table'] as Map) : null,
      signatures:
          json['signatures'] is Map ? AlignConfig.fromJson(json['signatures'] as Map) : null,
      typography:
          json['typography'] is Map
              ? TypographyConfig.fromJson(json['typography'] as Map)
              : null,
      branding:
          json['branding'] is Map ? BrandingConfig.fromJson(json['branding'] as Map) : null,
      defaults:
          json['defaults'] is Map
              ? Map<String, dynamic>.from(json['defaults'] as Map)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (page != null) 'page': page!.toJson(),
      if (header != null) 'header': header!.toJson(),
      if (body != null) 'body': body!.toJson(),
      if (table != null) 'table': table!.toJson(),
      if (signatures != null) 'signatures': signatures!.toJson(),
      if (typography != null) 'typography': typography!.toJson(),
      if (branding != null) 'branding': branding!.toJson(),
      if (defaults != null && defaults!.isNotEmpty) 'defaults': defaults,
    };
  }

  DocumentTemplateConfig copyWith({
    PageConfig? page,
    AlignConfig? header,
    AlignConfig? body,
    TableConfig? table,
    AlignConfig? signatures,
    TypographyConfig? typography,
    BrandingConfig? branding,
    Map<String, dynamic>? defaults,
  }) {
    return DocumentTemplateConfig(
      page: page ?? this.page,
      header: header ?? this.header,
      body: body ?? this.body,
      table: table ?? this.table,
      signatures: signatures ?? this.signatures,
      typography: typography ?? this.typography,
      branding: branding ?? this.branding,
      defaults: defaults ?? this.defaults,
    );
  }
}

class PageConfig {
  final int? paddingPx;
  final int? maxWidthPx;

  const PageConfig({this.paddingPx, this.maxWidthPx});

  factory PageConfig.fromJson(Map json) => PageConfig(
        paddingPx: json['paddingPx'] as int?,
        maxWidthPx: json['maxWidthPx'] as int?,
      );

  Map<String, dynamic> toJson() => {
        if (paddingPx != null) 'paddingPx': paddingPx,
        if (maxWidthPx != null) 'maxWidthPx': maxWidthPx,
      };
}

class AlignConfig {
  final String? align;

  const AlignConfig({this.align});

  factory AlignConfig.fromJson(Map json) => AlignConfig(align: json['align']?.toString());

  Map<String, dynamic> toJson() => {if (align != null) 'align': align};
}

class TableConfig {
  final String? headerAlign;
  final String? bodyAlign;
  final String? numberAlign;

  const TableConfig({this.headerAlign, this.bodyAlign, this.numberAlign});

  factory TableConfig.fromJson(Map json) => TableConfig(
        headerAlign: json['headerAlign']?.toString(),
        bodyAlign: json['bodyAlign']?.toString(),
        numberAlign: json['numberAlign']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        if (headerAlign != null) 'headerAlign': headerAlign,
        if (bodyAlign != null) 'bodyAlign': bodyAlign,
        if (numberAlign != null) 'numberAlign': numberAlign,
      };
}

class TypographyConfig {
  final int? baseFontPt;
  final int? titleFontPt;

  const TypographyConfig({this.baseFontPt, this.titleFontPt});

  factory TypographyConfig.fromJson(Map json) => TypographyConfig(
        baseFontPt: json['baseFontPt'] as int?,
        titleFontPt: json['titleFontPt'] as int?,
      );

  Map<String, dynamic> toJson() => {
        if (baseFontPt != null) 'baseFontPt': baseFontPt,
        if (titleFontPt != null) 'titleFontPt': titleFontPt,
      };
}

class BrandingConfig {
  final bool? showGeneratedFooter;
  final String? customFooterTextTa;
  final String? customFooterTextEn;

  const BrandingConfig({
    this.showGeneratedFooter,
    this.customFooterTextTa,
    this.customFooterTextEn,
  });

  factory BrandingConfig.fromJson(Map json) => BrandingConfig(
        showGeneratedFooter: json['showGeneratedFooter'] as bool?,
        customFooterTextTa: json['customFooterTextTa']?.toString(),
        customFooterTextEn: json['customFooterTextEn']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        if (showGeneratedFooter != null) 'showGeneratedFooter': showGeneratedFooter,
        if (customFooterTextTa != null && customFooterTextTa!.isNotEmpty)
          'customFooterTextTa': customFooterTextTa,
        if (customFooterTextEn != null && customFooterTextEn!.isNotEmpty)
          'customFooterTextEn': customFooterTextEn,
      };
}

class TemplateSettingsEntry {
  final String templateId;
  final String labelTa;
  final String labelEn;
  final DocumentTemplateConfig effective;
  final DocumentTemplateConfig? global;
  final DocumentTemplateConfig? panchayatOverride;
  final bool hasGlobal;
  final bool hasPanchayat;

  TemplateSettingsEntry({
    required this.templateId,
    required this.labelTa,
    required this.labelEn,
    required this.effective,
    this.global,
    this.panchayatOverride,
    this.hasGlobal = false,
    this.hasPanchayat = false,
  });

  factory TemplateSettingsEntry.fromJson(Map<String, dynamic> json) {
    final label = json['label'] is Map ? json['label'] as Map : {};
    final sources = json['sources'] is Map ? json['sources'] as Map : {};
    return TemplateSettingsEntry(
      templateId: json['template_id']?.toString() ?? '',
      labelTa: label['ta']?.toString() ?? '',
      labelEn: label['en']?.toString() ?? '',
      effective: DocumentTemplateConfig.fromJson(
        json['effective'] is Map ? json['effective'] as Map<String, dynamic> : null,
      ),
      global: json['global'] is Map
          ? DocumentTemplateConfig.fromJson(json['global'] as Map<String, dynamic>)
          : null,
      panchayatOverride: json['panchayat_override'] is Map
          ? DocumentTemplateConfig.fromJson(
              json['panchayat_override'] as Map<String, dynamic>,
            )
          : null,
      hasGlobal: sources['global'] == true,
      hasPanchayat: sources['panchayat'] == true,
    );
  }
}

const kDocumentTemplateIds = [
  'rfq',
  'quotation',
  'comparative',
  'work_order',
  'so_proceedings',
  'form19',
];

const kTextAlignOptions = ['left', 'center', 'right', 'justify'];
const kSignatureAlignOptions = ['left', 'center', 'right', 'justify', 'space-between'];
