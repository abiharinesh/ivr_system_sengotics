import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/modules/dms/data/document_repository.dart';

/// The document register.
///
/// This screen listed three hardcoded filenames — a gazette notification and
/// two blueprints that did not exist — while 200 real documents sat in 136
/// folders with no HTTP surface to reach them. It now browses the register:
/// a folder tree on the left, its contents on the right.
class DmsExplorerScreen extends StatefulWidget {
  const DmsExplorerScreen({super.key, this.repository});

  /// Injected by tests. The screen builds its own against the live API when
  /// this is null, so nothing at the call sites has to know it exists.
  final DocumentRepository? repository;

  @override
  State<DmsExplorerScreen> createState() => _DmsExplorerScreenState();
}

class _DmsExplorerScreenState extends State<DmsExplorerScreen> {
  late final _repo = widget.repository ?? DocumentRepository();
  final _search = TextEditingController();

  List<DocumentFolderNode> _folders = const [];
  List<DocumentRecord> _documents = const [];
  DocumentSummary _summary = DocumentSummary.empty;
  final Set<int> _open = {};

  int? _selectedFolder;
  bool _loading = true;
  bool _listLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.folders(),
        _repo.summary(),
        _repo.list(folderId: _selectedFolder, search: _search.text.trim()),
      ]);
      if (!mounted) return;
      setState(() {
        _folders = results[0] as List<DocumentFolderNode>;
        _summary = results[1] as DocumentSummary;
        _documents = results[2] as List<DocumentRecord>;
        _loading = false;
        // Top-level folders open by default; a collapsed tree on first load
        // hides the fact that anything is filed at all.
        if (_open.isEmpty) _open.addAll(_folders.map((f) => f.id));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadList() async {
    setState(() => _listLoading = true);
    try {
      final docs = await _repo.list(
        folderId: _selectedFolder,
        search: _search.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _documents = docs;
        _listLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _listLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _metrics(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              // The tree costs a third of a narrow window and the file list is
              // the point, so below this width it is dropped rather than
              // squeezed.
              if (c.maxWidth <= 820) return _fileList();
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 268, child: _tree()),
                  VerticalDivider(width: 1, color: AppTheme.stroke),
                  Expanded(child: _fileList()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _metrics() {
    Widget tile(String label, String value, IconData icon, {Color? accent}) {
      final c = accent ?? AppTheme.primary;
      return Container(
        width: 196,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.stroke),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: c),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          tile('documents on file', '${_summary.total}',
              Icons.folder_copy_rounded),
          tile('digitally signed', '${_summary.signed}', Icons.verified_rounded,
              accent: AppTheme.accent),
          tile('expiring in 30 days', '${_summary.expiringIn30Days}',
              Icons.event_busy_rounded,
              accent: _summary.expiringIn30Days == 0
                  ? AppTheme.accent
                  : AppTheme.warning),
          tile('total stored', _summary.readableSize, Icons.storage_rounded),
        ],
      ),
    );
  }

  // ── Folder tree ────────────────────────────────────────────────────────────

  Widget _tree() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 16),
      children: [
        _treeRow(
          id: null,
          name: 'All documents',
          count: _summary.total,
          depth: 0,
          icon: Icons.inbox_rounded,
        ),
        for (final f in _folders) ..._branch(f, 0),
      ],
    );
  }

  List<Widget> _branch(DocumentFolderNode f, int depth) {
    final expanded = _open.contains(f.id);
    return [
      _treeRow(
        id: f.id,
        name: f.name,
        count: f.documentCount,
        depth: depth,
        icon: expanded ? Icons.folder_open_rounded : Icons.folder_rounded,
        hasChildren: f.children.isNotEmpty,
        expanded: expanded,
        onToggle: f.children.isEmpty
            ? null
            : () => setState(() {
                  if (expanded) {
                    _open.remove(f.id);
                  } else {
                    _open.add(f.id);
                  }
                }),
      ),
      if (expanded)
        for (final c in f.children) ..._branch(c, depth + 1),
    ];
  }

  Widget _treeRow({
    required int? id,
    required String name,
    required int count,
    required int depth,
    required IconData icon,
    bool hasChildren = false,
    bool expanded = false,
    VoidCallback? onToggle,
  }) {
    final selected = _selectedFolder == id;
    return InkWell(
      onTap: () {
        setState(() => _selectedFolder = id);
        _loadList();
      },
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: EdgeInsets.fromLTRB(8 + depth * 14, 8, 8, 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.09)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            if (hasChildren)
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 17,
                  color: AppTheme.textMuted,
                ),
              )
            else
              const SizedBox(width: 17),
            const SizedBox(width: 4),
            Icon(
              icon,
              size: 16,
              color: selected ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppTheme.primary : AppTheme.textPrimary,
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── File list ──────────────────────────────────────────────────────────────

  Widget _fileList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onSubmitted: (_) => _loadList(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search by title or filename…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: AppTheme.bgCard,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(color: AppTheme.stroke),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide(color: AppTheme.stroke),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_documents.length} file(s)',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Reload',
                onPressed: _listLoading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: _listLoading
              ? const Center(child: CircularProgressIndicator())
              : _documents.isEmpty
                  ? _emptyFolder()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _documents.length,
                      itemBuilder: (context, i) => _fileRow(_documents[i]),
                    ),
        ),
      ],
    );
  }

  Widget _fileRow(DocumentRecord d) {
    final (icon, colour) = switch (d.kind) {
      'pdf' => (Icons.picture_as_pdf_rounded, AppTheme.error),
      'image' => (Icons.image_rounded, AppTheme.info),
      'sheet' => (Icons.table_chart_rounded, AppTheme.accent),
      'doc' => (Icons.description_rounded, AppTheme.primary),
      _ => (Icons.insert_drive_file_rounded, AppTheme.textMuted),
    };
    final fmt = DateFormat('d MMM yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: colour),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        d.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (d.isSigned) ...[
                      const SizedBox(width: 7),
                      Icon(Icons.verified_rounded,
                          size: 14, color: AppTheme.accent),
                    ],
                    if (d.version > 1) ...[
                      const SizedBox(width: 7),
                      Text(
                        'v${d.version}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    d.fileName,
                    d.readableSize,
                    if (d.createdAt != null) fmt.format(d.createdAt!.toLocal()),
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          if (d.module != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _pretty(d.module!),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyFolder() {
    final searching = _search.text.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.folder_off_rounded,
                  size: 26, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            Text(
              searching
                  ? 'Nothing matches that search'
                  : 'This folder is empty',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              searching
                  ? 'Try a different title or filename.'
                  : 'Documents filed here will appear in this list.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              'Could not load the register',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  static String _pretty(String raw) {
    if (raw.isEmpty) return raw;
    final s = raw.replaceAll('_', ' ');
    return s[0].toUpperCase() + s.substring(1);
  }
}
