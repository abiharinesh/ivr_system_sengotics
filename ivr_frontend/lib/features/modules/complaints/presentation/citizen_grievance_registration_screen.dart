import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';

class CitizenGrievanceRegistrationScreen extends StatefulWidget {
  const CitizenGrievanceRegistrationScreen({super.key});

  @override
  State<CitizenGrievanceRegistrationScreen> createState() => _CitizenGrievanceRegistrationScreenState();
}

class _CitizenGrievanceRegistrationScreenState extends State<CitizenGrievanceRegistrationScreen> {
  bool _isRecordingAudio = false;
  int _selectedCategoryIndex = 0;

  final List<Map<String, String>> _categories = [
    {'titleEn': 'Electrical & Lighting', 'titleTa': 'மின் பழுது', 'icon': 'flash_on'},
    {'titleEn': 'Roads & Potholes', 'titleTa': 'சாலை பழுது', 'icon': 'add_road'},
    {'titleEn': 'Water Supply & Leakage', 'titleTa': 'குடிநீர் பிரச்சனை', 'icon': 'water_drop'},
    {'titleEn': 'Solid Waste & Sanitation', 'titleTa': 'சுப்பாதாரம் & கழிவு', 'icon': 'delete'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Public Citizen Grievance Registration', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('பொதுமக்கள் குறைதீர்ப்பு மனு தாக்கல் பக்கம் (Voice Audio & Location Geotag)'),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.record_voice_over_rounded),
                label: const Text('Tamil Voice Assistance Mode'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Category selector
          const Text('Step 1: Select Complaint Category / பிரிவு தேர்ந்தெடுக்கவும்', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 2.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSel = _selectedCategoryIndex == index;
              return InkWell(
                onTap: () => setState(() => _selectedCategoryIndex = index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSel ? AppTheme.primary.withValues(alpha: 0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? AppTheme.primary : AppTheme.stroke, width: isSel ? 2 : 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(cat['titleEn']!, style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? AppTheme.primary : AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text(cat['titleTa']!, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          // Audio Voice Memo Recorder Component
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Step 2: Record Voice Memo in Tamil / English (குரல் பதிவு)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Tap record button to describe your complaint verbally without typing.'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _isRecordingAudio = !_isRecordingAudio),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecordingAudio ? Colors.red : AppTheme.primary,
                        ),
                        icon: Icon(_isRecordingAudio ? Icons.stop_rounded : Icons.mic_rounded),
                        label: Text(_isRecordingAudio ? 'Stop Recording (0:14s)' : 'Record Voice Audio Memo'),
                      ),
                      if (_isRecordingAudio) ...[
                        const SizedBox(width: 16),
                        const SizedBox(
                          width: 120,
                          height: 24,
                          child: LinearProgressIndicator(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Written Description (Optional text notes)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Map Geotag Picker
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Step 3: Geotagged Location & Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12)),
                    child: const Center(
                      child: Text('Interactive Map Pin Picker (Auto-detect Ward & GPS)'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.timer_rounded, color: AppTheme.primary),
                        const SizedBox(width: 10),
                        const Text('Guaranteed Resolution Target: Within 24 Business Hours (SLA Policy Tag)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit Grievance & Receive Tracking SMS / WhatsApp'),
            ),
          ),
        ],
      ),
    );
  }
}
