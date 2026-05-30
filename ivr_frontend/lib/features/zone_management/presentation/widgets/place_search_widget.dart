import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../models/zone_model.dart';

/// Widget for searching place names via OSM Nominatim proxy.
/// Shows autocomplete results with boundary polygon availability indicators.
class PlaceSearchWidget extends StatefulWidget {
  final Future<List<PlaceBoundaryResult>> Function(String query) onSearch;
  final ValueChanged<PlaceBoundaryResult> onPlaceSelected;
  final VoidCallback? onClear;

  const PlaceSearchWidget({
    super.key,
    required this.onSearch,
    required this.onPlaceSelected,
    this.onClear,
  });

  @override
  State<PlaceSearchWidget> createState() => _PlaceSearchWidgetState();
}

class _PlaceSearchWidgetState extends State<PlaceSearchWidget> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<PlaceBoundaryResult> _results = [];
  bool _isLoading = false;
  bool _showResults = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _showResults = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await widget.onSearch(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
          _showResults = results.isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showResults = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.stroke),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search places (e.g., village name)...',
              hintStyle:       TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
              prefixIcon:       Icon(
                Icons.search_rounded,
                size: 18,
                color: AppTheme.textMuted,
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _results = [];
                          _showResults = false;
                        });
                        widget.onClear?.call();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (_showResults && !_isLoading)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.stroke),
              boxShadow: AppTheme.softShadow,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    result.hasBoundary
                        ? Icons.crop_free_rounded
                        : Icons.location_on_rounded,
                    size: 18,
                    color: result.hasBoundary
                        ? AppTheme.accent
                        : AppTheme.textMuted,
                  ),
                  title: Text(
                    _shortenDisplayName(result.displayName),
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: result.hasBoundary
                              ? AppTheme.accent.withValues(alpha: 0.1)
                              : AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          result.type,
                          style: TextStyle(
                            fontSize: 10,
                            color: result.hasBoundary
                                ? AppTheme.accent
                                : AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (result.hasBoundary) ...[
                        const SizedBox(width: 6),
                              Text(
                          '• has boundary',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    widget.onPlaceSelected(result);
                    setState(() => _showResults = false);
                    _controller.text = _shortenDisplayName(result.displayName);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  String _shortenDisplayName(String name) {
    final parts = name.split(',');
    if (parts.length <= 3) return name;
    return '${parts[0].trim()}, ${parts[1].trim()}, ${parts[2].trim()}';
  }
}