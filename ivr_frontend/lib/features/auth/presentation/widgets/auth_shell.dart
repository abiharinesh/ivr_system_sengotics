import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';

/// The frame both sign-in and change-password sit in.
///
/// Shared so the two never drift apart: they are consecutive steps in the same
/// flow, and a change of typeface or card radius between them reads as landing
/// on a different product halfway through signing in.
///
/// On a narrow screen the aside is dropped entirely rather than stacked. It
/// carries no information the form needs, and keeping it pushes the fields
/// below the fold on a phone.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.child,
    required this.asideTitle,
    required this.asideBody,
    this.asideIcon = Icons.account_balance_rounded,
    this.asideFooter,
  });

  final Widget child;
  final String asideTitle;
  final String asideBody;
  final IconData asideIcon;
  final Widget? asideFooter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > 900;
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 940 : 460),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.stroke),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 40,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: wide
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(flex: 5, child: _aside()),
                                    Expanded(
                                      flex: 6,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            36, 40, 36, 32),
                                        child: Center(child: child),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(26, 34, 26, 28),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _compactBrand(),
                                    const SizedBox(height: 26),
                                    child,
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _aside() {
    return Container(
      padding: const EdgeInsets.fromLTRB(36, 40, 36, 32),
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(asideIcon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ooraatchi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'ஊராட்சி',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            asideTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            asideBody,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_in_talk_rounded, color: Colors.amber, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'DEMO IVR HELPLINES',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '📞 Main Helpline: 04440115043\n📞 Demo Trial Line: 04440115434',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Names what the platform actually covers. A government evaluator
          // opening this for the first time gets the scope before signing in.
          ..._points.map(_point),
          const Spacer(),
          if (asideFooter != null) asideFooter!,
          const SizedBox(height: 6),
          Text(
            'Tamil Nadu local body e-governance platform',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  static const _points = [
    (Icons.report_problem_rounded, 'Grievances & IVR'),
    (Icons.currency_rupee_rounded, 'Revenue & licensing'),
    (Icons.home_work_rounded, 'Permits & registration'),
    (Icons.engineering_rounded, 'Works & procurement'),
  ];

  Widget _point((IconData, String) p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Icon(p.$1, size: 16, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 11),
          Text(
            p.$2,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactBrand() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(asideIcon, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ooraatchi',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Tamil Nadu local body platform',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A soft field of colour behind the card. Cheap to paint and keeps the page
/// from reading as an empty grey rectangle at large window sizes.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BackdropPainter());
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppTheme.bgDark);

    void blob(Offset centre, double radius, Color color) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    final r = math.min(size.width, size.height) * 0.75;
    blob(Offset(size.width * 0.1, size.height * 0.08), r, AppTheme.primary);
    blob(Offset(size.width * 0.92, size.height * 0.9), r * 0.9, AppTheme.accent);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}
