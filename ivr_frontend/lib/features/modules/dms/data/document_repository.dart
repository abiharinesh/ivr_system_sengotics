import 'package:ivr_frontend/core/api/api_client.dart';

/// Models and reads for `/api/documents` — the document register.

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

DateTime? _date(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList()
    : const [];

/// A folder and everything filed beneath it.
class DocumentFolderNode {
  final int id;
  final String name;

  /// Includes documents in child folders — a top-level folder that counted
  /// only its own would read as empty while holding the lot.
  final int documentCount;
  final List<DocumentFolderNode> children;

  const DocumentFolderNode({
    required this.id,
    required this.name,
    required this.documentCount,
    required this.children,
  });

  factory DocumentFolderNode.fromJson(Map<String, dynamic> j) =>
      DocumentFolderNode(
        id: _int(j['id']),
        name: j['name'] as String? ?? '',
        documentCount: _int(j['document_count']),
        children: _maps(j['children']).map(DocumentFolderNode.fromJson).toList(),
      );
}

class DocumentRecord {
  final int id;
  final String title;
  final String fileName;
  final String? fileUrl;
  final int? sizeBytes;
  final String? mimeType;
  final int version;
  final String? module;
  final String? entityType;
  final int? entityId;
  final int? folderId;
  final List<String> tags;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final bool isSigned;

  const DocumentRecord({
    required this.id,
    required this.title,
    required this.fileName,
    required this.fileUrl,
    required this.sizeBytes,
    required this.mimeType,
    required this.version,
    required this.module,
    required this.entityType,
    required this.entityId,
    required this.folderId,
    required this.tags,
    required this.expiresAt,
    required this.createdAt,
    required this.isSigned,
  });

  /// Drives the icon. A blueprint and a photograph are not read the same way.
  String get kind {
    final m = mimeType ?? '';
    if (m.contains('pdf')) return 'pdf';
    if (m.startsWith('image/')) return 'image';
    if (m.contains('sheet') || m.contains('excel')) return 'sheet';
    if (m.contains('word') || m.contains('document')) return 'doc';
    return 'file';
  }

  String get readableSize {
    final b = sizeBytes ?? 0;
    if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).round()} KB';
    return '$b B';
  }

  factory DocumentRecord.fromJson(Map<String, dynamic> j) => DocumentRecord(
        id: _int(j['id']),
        title: j['title'] as String? ?? '',
        fileName: j['file_name'] as String? ?? '',
        fileUrl: j['file_url'] as String?,
        sizeBytes:
            j['file_size_bytes'] == null ? null : _int(j['file_size_bytes']),
        mimeType: j['mime_type'] as String?,
        version: _int(j['version'], 1),
        module: j['module'] as String?,
        entityType: j['entity_type'] as String?,
        entityId: j['entity_id'] == null ? null : _int(j['entity_id']),
        folderId: j['folder_id'] == null ? null : _int(j['folder_id']),
        tags: (j['tags'] as List? ?? []).map((e) => e.toString()).toList(),
        expiresAt: _date(j['expires_at']),
        createdAt: _date(j['created_at']),
        isSigned: j['is_signed'] == true,
      );
}

class DocumentSummary {
  final int total;
  final int signed;
  final int expiringIn30Days;
  final int totalBytes;
  final List<MapEntry<String, int>> byModule;

  const DocumentSummary({
    required this.total,
    required this.signed,
    required this.expiringIn30Days,
    required this.totalBytes,
    required this.byModule,
  });

  static const empty = DocumentSummary(
    total: 0,
    signed: 0,
    expiringIn30Days: 0,
    totalBytes: 0,
    byModule: [],
  );

  String get readableSize {
    if (totalBytes >= 1073741824) {
      return '${(totalBytes / 1073741824).toStringAsFixed(1)} GB';
    }
    if (totalBytes >= 1048576) {
      return '${(totalBytes / 1048576).round()} MB';
    }
    return '${(totalBytes / 1024).round()} KB';
  }

  factory DocumentSummary.fromJson(Map<String, dynamic> j) => DocumentSummary(
        total: _int(j['total']),
        signed: _int(j['signed']),
        expiringIn30Days: _int(j['expiring_in_30_days']),
        totalBytes: _int(j['total_bytes']),
        byModule: _maps(j['by_module'])
            .map((e) => MapEntry(e['module'] as String? ?? '', _int(e['count'])))
            .toList(),
      );
}

class DocumentRepository {
  final ApiClient _api;

  DocumentRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static const String _base = '/api/documents';

  Future<List<DocumentFolderNode>> folders() async {
    final data = await _api.get('$_base/folders', forceRefresh: true);
    return (data as List)
        .map((e) => DocumentFolderNode.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<DocumentSummary> summary() async {
    final data = await _api.get('$_base/summary', forceRefresh: true);
    return DocumentSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<DocumentRecord>> list({int? folderId, String? search}) async {
    final data = await _api.get(
      _base,
      queryParams: {
        if (folderId != null) 'folder_id': '$folderId',
        if (search != null && search.isNotEmpty) 'search': search,
      },
      forceRefresh: true,
    );
    return (data as List)
        .map((e) => DocumentRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
