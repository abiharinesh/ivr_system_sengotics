import 'package:flutter/material.dart';

class AssetRegistrationScreen extends StatefulWidget {
  const AssetRegistrationScreen({super.key});

  @override
  State<AssetRegistrationScreen> createState() => _AssetRegistrationScreenState();
}

class _AssetRegistrationScreenState extends State<AssetRegistrationScreen> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dynamic Asset Registration Wizard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Register new municipal physical asset with dynamic type parameters and GPS capture.'),
          const SizedBox(height: 24),
          Stepper(
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep < 3) setState(() => _currentStep++);
            },
            onStepCancel: () {
              if (_currentStep > 0) setState(() => _currentStep--);
            },
            steps: [
              Step(
                title: const Text('Step 1: Category & General Info'),
                content: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: 'Street Light',
                      decoration: const InputDecoration(labelText: 'Asset Category Type'),
                      items: const [
                        DropdownMenuItem(value: 'Street Light', child: Text('Street Light / Electric Pole')),
                        DropdownMenuItem(value: 'Water Pump', child: Text('Water Pump / Borewell')),
                        DropdownMenuItem(value: 'Park', child: Text('Public Park / Open Space')),
                      ],
                      onChanged: (v) {},
                    ),
                    const SizedBox(height: 12),
                    TextFormField(decoration: const InputDecoration(labelText: 'Asset Code (Auto-generated if empty)')),
                    const SizedBox(height: 12),
                    TextFormField(decoration: const InputDecoration(labelText: 'Asset Display Name')),
                  ],
                ),
              ),
              Step(
                title: const Text('Step 2: Dynamic Category Parameters (Asset.custom_data)'),
                content: Column(
                  children: [
                    TextFormField(decoration: const InputDecoration(labelText: 'Wattage Rating (Watts)')),
                    const SizedBox(height: 12),
                    TextFormField(decoration: const InputDecoration(labelText: 'Pole Height (Meters)')),
                  ],
                ),
              ),
              Step(
                title: const Text('Step 3: Geolocation GPS Capture'),
                content: Column(
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.my_location), label: const Text('Fetch Current GPS')),
                        const SizedBox(width: 16),
                        const Text('Lat: 9.9824 • Lng: 77.7981 (Accuracy: 3m)'),
                      ],
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Step 4: Image & Warranty Upload'),
                content: Column(
                  children: [
                    OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.camera_alt), label: const Text('Capture Asset Photo')),
                    const SizedBox(height: 12),
                    TextFormField(decoration: const InputDecoration(labelText: 'Warranty Provider & Expiry')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
