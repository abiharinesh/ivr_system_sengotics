import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/api/api_client.dart';

/// Phase 9: Citizen Portal screen — announcements and feedback
class CitizenPortalScreen extends StatefulWidget {
  const CitizenPortalScreen({super.key});

  @override
  State<CitizenPortalScreen> createState() => _CitizenPortalScreenState();
}

class _CitizenPortalScreenState extends State<CitizenPortalScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<dynamic> _announcements = [];
  bool _loadingAnn = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAnnouncements();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _loadingAnn = true);
    try {
      final res = await ApiClient.instance.get('/api/citizen-portal/announcements');
      setState(() { _announcements = List<dynamic>.from(res['data'] ?? res ?? []); });
    } catch (_) {
    } finally {
      setState(() => _loadingAnn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Column(
        children: [
          Container(
            color: AppTheme.bgCard,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textMuted,
              tabs: const [
                Tab(icon: Icon(Icons.campaign_outlined), text: 'Announcements'),
                Tab(icon: Icon(Icons.rate_review_outlined), text: 'Feedback'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _AnnouncementsTab(announcements: _announcements, isLoading: _loadingAnn, onRefresh: _loadAnnouncements),
                const _FeedbackTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementsTab extends StatelessWidget {
  final List<dynamic> announcements;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _AnnouncementsTab({required this.announcements, required this.isLoading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (announcements.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.campaign_outlined, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text('No announcements at the moment.', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: announcements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _AnnouncementCard(ann: announcements[i] as Map<String, dynamic>),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> ann;
  const _AnnouncementCard({required this.ann});

  @override
  Widget build(BuildContext context) {
    final isPinned = ann['is_pinned'] == true;
    final category = ann['category']?.toString() ?? 'general';
    final createdAt = ann['published_at'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(ann['published_at'].toString()).toLocal())
        : '—';

    final categoryColors = {
      'water': Colors.blue,
      'health': Colors.pink,
      'road': Colors.orange,
      'general': AppTheme.primary,
    };
    final catColor = categoryColors[category] ?? AppTheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: isPinned ? AppTheme.primary.withValues(alpha: 0.5) : AppTheme.stroke),
        boxShadow: isPinned ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.12), blurRadius: 8)] : AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPinned) ...[
                const Icon(Icons.push_pin_rounded, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: catColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(category.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: catColor)),
              ),
              const Spacer(),
              Text(createdAt, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(ann['title']?.toString() ?? '—',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(ann['body']?.toString() ?? '—',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4), maxLines: 4, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();

  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab> {
  final _commentCtrl = TextEditingController();
  int _rating = 4;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.rate_review_outlined, color: Colors.white, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Share your feedback', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Help us improve our services', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Rating', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          Text('Your feedback', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _commentCtrl,
            maxLines: 5,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Share your experience or suggestions...',
              hintStyle: TextStyle(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.bgSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.stroke)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit Feedback'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_commentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your feedback before submitting.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ApiClient.instance.post('/api/citizen-portal/feedback', data: {
        'rating': _rating,
        'comment': _commentCtrl.text.trim(),
      });
      if (mounted) {
        _commentCtrl.clear();
        setState(() { _rating = 4; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you! Your feedback has been submitted.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
