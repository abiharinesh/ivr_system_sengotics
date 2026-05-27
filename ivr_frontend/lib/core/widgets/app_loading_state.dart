import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import 'app_card.dart';

class AppLoadingState extends StatefulWidget {
  final String message;
  final bool compact;
  final bool showSkeleton;
  final int skeletonLines;

  const AppLoadingState({
    super.key,
    this.message = 'Loading...',
    this.compact = false,
    this.showSkeleton = true,
    this.skeletonLines = 4,
  });

  @override
  State<AppLoadingState> createState() => _AppLoadingStateState();
}

class _AppLoadingStateState extends State<AppLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.45,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppTheme.spaceXs),
          Text(
            widget.message,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            widget.message,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          if (widget.showSkeleton) ...[
            const SizedBox(height: AppTheme.spaceLg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AppCard(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: FadeTransition(
                  opacity: _pulse,
                  child: Column(
                    children: List.generate(widget.skeletonLines, (index) {
                      final widthFactor = switch (index % 3) {
                        0 => 1.0,
                        1 => 0.85,
                        _ => 0.65,
                      };
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              index == widget.skeletonLines - 1
                                  ? 0
                                  : AppTheme.spaceSm,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: widthFactor,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppTheme.bgSurface,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSm,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
