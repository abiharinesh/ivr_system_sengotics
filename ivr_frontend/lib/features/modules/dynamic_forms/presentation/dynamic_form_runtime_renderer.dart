import 'package:flutter/material.dart';

class DynamicFormRuntimeRenderer extends StatefulWidget {
  final Map<String, dynamic>? formSchema;
  const DynamicFormRuntimeRenderer({super.key, this.formSchema});

  @override
  State<DynamicFormRuntimeRenderer> createState() => _DynamicFormRuntimeRendererState();
}

class _DynamicFormRuntimeRendererState extends State<DynamicFormRuntimeRenderer> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dynamic Runtime Form Renderer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dynamic Schema Compiled Form', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Applicant Aadhaar Number (12 Digits) *'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Aadhaar is required';
                  if (v.length != 12) return 'Must be 12 digits';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Proposed Building Height (Meters)'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.upload_file), label: const Text('Upload Blueprint PDF')),
              const SizedBox(height: 28),
              Row(
                children: [
                  OutlinedButton(onPressed: () {}, child: const Text('Save as Draft')),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dynamic Form Submitted Successfully!')));
                      }
                    },
                    child: const Text('Submit Form Application'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
