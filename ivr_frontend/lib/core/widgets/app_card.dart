import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderRadiusGeometry? borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool interactive;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius,
    this.onTap,
    this.onLongPress,
    this.interactive = false,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusLg);
    final inkRadius =
        widget.borderRadius is BorderRadius
            ? widget.borderRadius as BorderRadius
            : BorderRadius.circular(AppTheme.radiusLg);
    final shouldAnimate =
        widget.interactive ||
        widget.onTap != null ||
        widget.onLongPress != null;
    final shadow =
        _pressed
            ? const <BoxShadow>[]
            : (_hovered && shouldAnimate
                ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
                : AppTheme.softShadow);

    final card = AnimatedContainer(
      duration: AppTheme.durationFast,
      curve: Curves.easeOutCubic,
      margin: widget.margin,
      padding: widget.padding ?? const EdgeInsets.all(AppTheme.spaceMd),
      transform: Matrix4.translationValues(
        0.0,
        shouldAnimate && _hovered ? -1.5 : 0.0,
        0.0,
      ),
      decoration: BoxDecoration(
        color: widget.color ?? AppTheme.bgCard,
        borderRadius: radius,
        border: Border.all(
          color:
              shouldAnimate && _hovered
                  ? AppTheme.primary.withValues(alpha: 0.25)
                  : AppTheme.stroke,
        ),
        boxShadow: shadow,
      ),
      child: widget.child,
    );

    if (!shouldAnimate) return card;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:
          (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
      child: Material(
        color: Colors.transparent,
        borderRadius: inkRadius,
        child: InkWell(
          borderRadius: inkRadius,
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          splashColor: AppTheme.primary.withValues(alpha: 0.08),
          highlightColor: AppTheme.primary.withValues(alpha: 0.05),
          child: card,
        ),
      ),
    );
  }
}
