import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../config/api_config.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../data/tender_repository.dart';

/// Public-facing tender view. No authentication. Used by sellers via
/// `/public/open/:token` to read details and submit a quotation.
class PublicTenderScreen extends StatefulWidget {
  final String token;
  final bool useLegacyEndpoint;
  const PublicTenderScreen({
    super.key,
    required this.token,
    this.useLegacyEndpoint = false,
  });

  @override
  State<PublicTenderScreen> createState() => _PublicTenderScreenState();
}

class _PublicTenderScreenState extends State<PublicTenderScreen> {
  final _repo = TenderRepository();
  Future<Map<String, dynamic>>? _future;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _remarks = TextEditingController();
  final _picker = ImagePicker();
  XFile? _attachment;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = widget.useLegacyEndpoint
        ? _repo.readPublicTender(widget.token)
        : _repo.readPublicOpenTender(widget.token);
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty || _amount.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name, phone, and amount are required')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = widget.useLegacyEndpoint
          ? await _repo.submitPublicQuotation(
              widget.token,
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              amount: _amount.text.trim(),
              remarks:
                  _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
              attachment: _attachment,
            )
          : await _repo.submitPublicOpenQuotation(
              widget.token,
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              amount: _amount.text.trim(),
              remarks:
                  _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
              attachment: _attachment,
            );
      if (!mounted) return;
      final priorId = res['superseded_prior_id'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(priorId == null
            ? 'Quotation submitted. Thank you!'
            : 'Quotation updated (your earlier bid #$priorId was replaced).'),
      ));
      _amount.clear();
      _remarks.clear();
      setState(() => _attachment = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit your quotation')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
              message: 'Loading tender...',
              style: AppLoadingStyle.detail,
            );
          }
          if (snap.hasError) {
            final msg = userFacingMessage(snap.error!);
            final hint = snap.error is NotFoundException &&
                    msg.toLowerCase().contains('cannot get')
                ? '\n\nTip: run the backend locally (npm run start:dev) and launch Flutter with '
                    '"Flutter Web (Chrome, local API)". API host: ${ApiConfig.baseUrl}'
                : '';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: $msg$hint', textAlign: TextAlign.center),
              ),
            );
          }
          final data = snap.data!;
          final tender = (data['tender'] ?? {}) as Map<String, dynamic>;
          final panchayat = (data['panchayat'] ?? {}) as Map<String, dynamic>;
          final timeline = (data['timeline'] ?? {}) as Map<String, dynamic>;
          final lineItems = ((data['line_items'] ?? []) as List).cast<Map<String, dynamic>>();
          final df = DateFormat.yMMMd();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(panchayat['name']?.toString() ?? '', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                  Text(
                    tender['title_en']?.toString() ?? tender['title_ta']?.toString() ?? 'Tender #${tender['id']}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (tender['title_ta'] != null)
                    Text(tender['title_ta'].toString(), style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status: ${tender['status']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (timeline['quotation_deadline'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Quotation deadline: ${timeline['quotation_deadline']}'),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Mode: ${tender['quotation_access_mode']}'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if ((tender['narrative_en'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Work narrative', style: Theme.of(context).textTheme.titleMedium),
                    Text(tender['narrative_en'].toString()),
                  ],
                  if (lineItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Items', style: Theme.of(context).textTheme.titleMedium),
                    for (final li in lineItems)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(child: Text('${li['seq']}')),
                        title: Text(li['description_en']?.toString() ?? li['description_ta']?.toString() ?? '—'),
                        subtitle: Text(
                            '${li['quantity'] ?? ''} ${li['unit'] ?? ''}'.trim()),
                      ),
                  ],
                  const Divider(height: 32),
                  Text('Submit your quotation', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'Your name')),
                  TextField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Phone (10 digits)'),
                    keyboardType: TextInputType.phone,
                  ),
                  TextField(
                    controller: _amount,
                    decoration: const InputDecoration(labelText: 'Amount (₹)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks (optional)')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final f = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (f != null) setState(() => _attachment = f);
                        },
                        icon: const Icon(Icons.attach_file_outlined),
                        label: Text(_attachment == null
                            ? 'Attach photo (optional)'
                            : 'Change attachment'),
                      ),
                      if (_attachment != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _attachment!.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => setState(() => _attachment = null),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit quotation'),
                  ),
                  const SizedBox(height: 8),
                  Text('By submitting you agree the panchayat may contact you on the phone number provided.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('Submitted at ${df.format(DateTime.now())}',
                      style: const TextStyle(color: Colors.black45, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
