import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_client.dart';
import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/core/download/browser_download.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';

class QrCustomizerScreen extends StatefulWidget {
  final int poleId;
  const QrCustomizerScreen({super.key, required this.poleId});

  @override
  State<QrCustomizerScreen> createState() => _QrCustomizerScreenState();
}

class _QrCustomizerScreenState extends State<QrCustomizerScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final ApiClient _api = ApiClient.instance;

  // Customization variables
  String _headerText = 'OORAATCHI LOCAL BODY';
  String _subtextEn = 'Scan to report street light fault';
  String _subtextTa = 'பழுதுபார்க்க ஸ்கேன் செய்யவும்';
  String _footerText = 'Helpline: 1800-425-1234';

  Color _foregroundColor = Colors.black;
  Color _backgroundColor = Colors.white;

  QrEyeShape _eyeShape = QrEyeShape.square;
  QrDataModuleShape _dataShape = QrDataModuleShape.square;
  int _errorLevel = QrErrorCorrectLevel.H;
  bool _embedEmblem = true;

  Map<String, dynamic>? _poleData;
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _fetchPoleInfo();
  }

  Future<void> _fetchPoleInfo() async {
    try {
      final res = await _api.get(ApiConfig.publicQrUrl(widget.poleId));
      if (mounted) {
        setState(() {
          _poleData = Map<String, dynamic>.from(res as Map);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load pole information: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _exportAsPng() async {
    setState(() => _exporting = true);
    try {
      // Delay to ensure rendering is complete
      await Future.delayed(const Duration(milliseconds: 150));

      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Sticker boundary not found');

      // Capture canvas at 3.0x scaling ratio for print-ready high density resolution
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to generate PNG bytes');

      final pngBytes = byteData.buffer.asUint8List();
      final poleNum = _poleData?['pole_number'] ?? 'pole-${widget.poleId}';

      await saveBytes(
        bytes: pngBytes,
        filename: 'sticker-$poleNum.png',
        contentType: 'image/png',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sticker QR exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export QR: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: AppLoadingState(message: 'Loading customizer canvas...'),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('QR Code Customizer')),
        body: Center(
          child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
        ),
      );
    }

    final poleNum = _poleData?['pole_number'] as String? ?? 'N/A';
    final reportUrl = _poleData?['url'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text('Design QR Sticker: Pole #$poleNum'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          final view = isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildCanvasPreview(reportUrl, poleNum)),
                    VerticalDivider(width: 1, color: AppTheme.stroke),
                    Expanded(flex: 2, child: _buildControlsPanel()),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCanvasPreview(reportUrl, poleNum, height: 480),
                      const Divider(height: 1),
                      _buildControlsPanel(),
                    ],
                  ),
                );
          return view;
        },
      ),
    );
  }

  Widget _buildCanvasPreview(String reportUrl, String poleNum, {double? height}) {
    return Container(
      height: height,
      alignment: Alignment.center,
      color: AppTheme.bgDark,
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // RepaintBoundary holds the actual printable area
            RepaintBoundary(
              key: _canvasKey,
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Logo placeholder / Emblem
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_city_rounded, color: _foregroundColor, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _headerText.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: _foregroundColor,
                              letterSpacing: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: _foregroundColor.withValues(alpha: 0.3), thickness: 1.5),
                    const SizedBox(height: 20),

                    // Instruction text (English & Tamil)
                    if (_subtextEn.isNotEmpty) ...[
                      Text(
                        _subtextEn,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _foregroundColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (_subtextTa.isNotEmpty) ...[
                      Text(
                        _subtextTa,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _foregroundColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Customized QR Code
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _foregroundColor.withValues(alpha: 0.15), width: 1.5),
                      ),
                      child: QrImageView(
                        data: reportUrl,
                        version: QrVersions.auto,
                        size: 200,
                        gapless: false,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: _errorLevel,
                        eyeStyle: QrEyeStyle(
                          eyeShape: _eyeShape,
                          color: _foregroundColor,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: _dataShape,
                          color: _foregroundColor,
                        ),
                        embeddedImage: _embedEmblem
                            ? const AssetImage('assets/redesign/backgrounds/hero_logo.jpg') // Emblem fallback
                            : null,
                        embeddedImageStyle: const QrEmbeddedImageStyle(
                          size: Size(30, 30),
                        ),
                        errorStateBuilder: (c, e) => const Center(
                          child: Text(
                            'QR Error',
                            style: TextStyle(color: AppTheme.error),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Divider(color: _foregroundColor.withValues(alpha: 0.3), thickness: 1.5),
                    const SizedBox(height: 12),

                    // Pole Metadata reference
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _foregroundColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'POLE NUMBER: $poleNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: _foregroundColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_footerText.isNotEmpty)
                      Text(
                        _footerText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _foregroundColor.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Canvas resolution captured at print quality (300 DPI equivalent)',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DESIGN CONTROLS',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                // Text customizations
                _buildTextField('Header Title', _headerText, (val) => setState(() => _headerText = val)),
                const SizedBox(height: 12),
                _buildTextField('Instruction (English)', _subtextEn, (val) => setState(() => _subtextEn = val)),
                const SizedBox(height: 12),
                _buildTextField('Instruction (Tamil)', _subtextTa, (val) => setState(() => _subtextTa = val)),
                const SizedBox(height: 12),
                _buildTextField('Footer Helpline', _footerText, (val) => setState(() => _footerText = val)),
                
                const Divider(height: 32),

                // Styling configs
                const Text('QR Styling & Matrix Shape', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<QrEyeShape>(
                        initialValue: _eyeShape,
                        decoration: const InputDecoration(labelText: 'Eye Shape'),
                        items: const [
                          DropdownMenuItem(value: QrEyeShape.square, child: Text('Square')),
                          DropdownMenuItem(value: QrEyeShape.circle, child: Text('Circle')),
                        ],
                        onChanged: (val) => setState(() => _eyeShape = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<QrDataModuleShape>(
                        initialValue: _dataShape,
                        decoration: const InputDecoration(labelText: 'Matrix Dots'),
                        items: const [
                          DropdownMenuItem(value: QrDataModuleShape.square, child: Text('Square')),
                          DropdownMenuItem(value: QrDataModuleShape.circle, child: Text('Circle (Rounded)')),
                        ],
                        onChanged: (val) => setState(() => _dataShape = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Error correction level
                DropdownButtonFormField<int>(
                  initialValue: _errorLevel,
                  decoration: const InputDecoration(labelText: 'Error Correction Level'),
                  items: const [
                    DropdownMenuItem<int>(value: QrErrorCorrectLevel.L, child: Text('Low (7%)')),
                    DropdownMenuItem<int>(value: QrErrorCorrectLevel.M, child: Text('Medium (15%)')),
                    DropdownMenuItem<int>(value: QrErrorCorrectLevel.Q, child: Text('Quarter (25%)')),
                    DropdownMenuItem<int>(value: QrErrorCorrectLevel.H, child: Text('High (30% - Best for outdoors)')),
                  ],
                  onChanged: (val) => setState(() => _errorLevel = val!),
                ),
                const SizedBox(height: 16),

                // Embedded Logo Toggle
                CheckboxListTile(
                  value: _embedEmblem,
                  title: const Text('Embed Panchayat Logo in Center', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _embedEmblem = val ?? false),
                ),

                const Divider(height: 32),

                // Color selectors
                const Text('Sticker Card Colors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _colorOption(Colors.black, 'Black', true),
                    _colorOption(const Color(0xFF1E3A8A), 'Navy', true),
                    _colorOption(const Color(0xFF0F766E), 'Teal', true),
                    _colorOption(const Color(0xFF15803D), 'Green', true),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _colorOption(Colors.white, 'White', false),
                    _colorOption(const Color(0xFFF9FAFB), 'Off-White', false),
                    _colorOption(const Color(0xFFF3F4F6), 'Light Grey', false),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Download PNG Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _exporting ? null : _exportAsPng,
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(_exporting ? 'Generating PNG...' : 'Export Sticker as PNG'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String value, Function(String) onChanged) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: onChanged,
    );
  }

  Widget _colorOption(Color color, String name, bool isForeground) {
    final isSelected = isForeground ? _foregroundColor == color : _backgroundColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isForeground) {
            _foregroundColor = color;
          } else {
            _backgroundColor = color;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
        ),
      ),
    );
  }
}
