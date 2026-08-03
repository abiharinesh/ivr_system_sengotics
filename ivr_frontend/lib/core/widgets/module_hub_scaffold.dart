import 'package:flutter/material.dart';

import 'package:ivr_frontend/config/app_theme.dart';

/// One tab inside a module hub.
class HubTab {
  final IconData icon;
  final String label;

  /// Built lazily so an unopened tab does not fire its screen's network calls.
  final WidgetBuilder builder;

  const HubTab({
    required this.icon,
    required this.label,
    required this.builder,
  });
}

/// Shell for a screen that merges several closely-related screens into one
/// destination.
///
/// Exists because the sidebar had grown a separate top-level entry for every
/// screen ever built — three entries for field workforce, two for IVR, three
/// for settings — which pushed genuinely different areas of the product below
/// the fold. A hub is one sidebar entry and one place to look; the tabs inside
/// are the variations of the same job.
class ModuleHubScaffold extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<HubTab> tabs;

  /// Optional index to open on, e.g. when a deep link targets one tab.
  final int initialIndex;

  const ModuleHubScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tabs,
    this.initialIndex = 0,
  });

  @override
  State<ModuleHubScaffold> createState() => _ModuleHubScaffoldState();
}

class _ModuleHubScaffoldState extends State<ModuleHubScaffold>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, widget.tabs.length - 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.stroke)),
          ),
          child: TabBar(
            controller: _controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final t in widget.tabs)
                Tab(icon: Icon(t.icon, size: 20), text: t.label),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              for (final t in widget.tabs) Builder(builder: t.builder),
            ],
          ),
        ),
      ],
    );
  }
}
