import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/features/modules/tenders/data/tender_repository.dart';

/// Invite-only tender landing. Accessed via `/public/invite/:token`.
class InviteTenderScreen extends StatefulWidget {
  final String token;
  const InviteTenderScreen({super.key, required this.token});

  @override
  State<InviteTenderScreen> createState() => _InviteTenderScreenState();
}

class _InviteTenderScreenState extends State<InviteTenderScreen> {
  final _repo = TenderRepository();
  Future<Map<String, dynamic>>? _future;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _remarks = TextEditingController();
  final _picker = ImagePicker();
  XFile? _attachment;
  bool _submitting = false;
  bool _vendorPrefilled = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.readInviteTender(widget.token);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _amount.dispose();
    _remarks.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _vendorPrefilled = false;
      _future = _repo.readInviteTender(widget.token);
    });
  }

  void _prefillVendorOnce(Map<String, dynamic> vendor) {
    if (_vendorPrefilled) return;
    _vendorPrefilled = true;
    _name.text = vendor['name']?.toString() ?? '';
    _phone.text = vendor['phone_e164']?.toString() ?? '';
  }

  Future<void> _submit({required bool canSubmit}) async {
    if (!canSubmit) return;
    if (_amount.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Amount is required')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await _repo.submitInviteQuotation(
        widget.token,
        name: _name.text.trim(),
        amount: _amount.text.trim(),
        remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
        attachment: _attachment,
      );
      if (!mounted) return;
      final priorId = res['superseded_prior_id'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            priorId == null
                ? 'Quotation submitted successfully.'
                : 'Updated your quotation (previous bid #$priorId replaced).',
          ),
        ),
      );
      _amount.clear();
      _remarks.clear();
      setState(() => _attachment = null);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor invitation')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
              message: 'Loading invite...',
              style: AppLoadingStyle.detail,
            );
          }
          if (snap.hasError) {
            return AppErrorState(
              message: userFacingMessage(snap.error!),
              onRetry: _reload,
            );
          }
          final data = snap.data!;
          final tender = (data['tender'] ?? {}) as Map<String, dynamic>;
          final panchayat = (data['org_unit'] ?? {}) as Map<String, dynamic>;
          final timeline = (data['timeline'] ?? {}) as Map<String, dynamic>;
          final invite = (data['invite'] ?? {}) as Map<String, dynamic>;
          final vendor = (invite['contractor'] ?? {}) as Map<String, dynamic>;
          final lineItems =
              ((data['line_items'] ?? []) as List).cast<Map<String, dynamic>>();

          _prefillVendorOnce(vendor);

          final tenderStatus = tender['status']?.toString() ?? '';
          final canSubmit = tenderStatus == 'published';
          final vendorName = vendor['name']?.toString() ?? 'Invited vendor';
          final df = DateFormat.yMMMd();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    panchayat['name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  Text(
                    tender['title_en']?.toString() ??
                        tender['title_ta']?.toString() ??
                        'Tender #${tender['id']}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mail_outline,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Invitation for $vendorName',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!canSubmit) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          tenderStatus == 'quotations_closed'
                              ? 'This tender is no longer accepting quotations.'
                              : 'This tender is not open for quotations (status: $tenderStatus).',
                        ),
                      ),
                    ),
                  ],
                  if (invite['submitted_at'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'You already submitted a quotation. Submit again below to replace it.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your details (from invitation)'),
                          const SizedBox(height: 6),
                          Text('Name: ${vendor['name'] ?? '—'}'),
                          Text('Phone: ${vendor['phone_e164'] ?? '—'}'),
                          if (timeline['quotation_deadline'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Quotation deadline: ${timeline['quotation_deadline']}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if ((tender['narrative_en'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Work narrative',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(tender['narrative_en'].toString()),
                  ],
                  if (lineItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final li in lineItems)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(child: Text('${li['seq']}')),
                        title: Text(
                          li['description_en']?.toString() ??
                              li['description_ta']?.toString() ??
                              '—',
                        ),
                        subtitle: Text(
                          '${li['quantity'] ?? ''} ${li['unit'] ?? ''}'.trim(),
                        ),
                      ),
                  ],
                  const Divider(height: 32),
                  Text(
                    'Your quotation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Vendor name',
                      helperText: 'Fixed for this invite link',
                    ),
                  ),
                  TextField(
                    controller: _phone,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      helperText: 'Fixed for this invite link',
                    ),
                  ),
                  TextField(
                    controller: _amount,
                    enabled: canSubmit,
                    decoration: const InputDecoration(labelText: 'Amount (₹)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: _remarks,
                    enabled: canSubmit,
                    decoration: const InputDecoration(labelText: 'Remarks'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            !canSubmit
                                ? null
                                : () async {
                                  final f = await _picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 85,
                                  );
                                  if (f != null)
                                    setState(() => _attachment = f);
                                },
                        icon: const Icon(Icons.attach_file_outlined),
                        label: Text(
                          _attachment == null
                              ? 'Attach photo (optional)'
                              : 'Change attachment',
                        ),
                      ),
                      if (_attachment != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _attachment!.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _attachment = null),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        _submitting || !canSubmit
                            ? null
                            : () => _submit(canSubmit: canSubmit),
                    child:
                        _submitting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Submit quotation'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Submitted at ${df.format(DateTime.now())}',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
