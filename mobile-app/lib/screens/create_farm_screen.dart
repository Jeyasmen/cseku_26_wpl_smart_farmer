import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class CreateFarmScreen extends StatefulWidget {
  const CreateFarmScreen({super.key});

  @override
  State<CreateFarmScreen> createState() => _CreateFarmScreenState();
}

class _CreateFarmScreenState extends State<CreateFarmScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _farmSizeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedUnit = 'শতাংশ (Decimal)';
  String? _selectedSoilType = 'Loamy (দোআঁশ)';

  final List<String> _landUnits = [
    'শতাংশ (Decimal)',
    'বিঘা (Bigha)',
    'একর (Acre)',
    'কাঠা (Katha)',
  ];

  final List<String> _soilTypes = [
    'Loamy (দোআঁশ)',
    'Sandy Loam (বেলে-দোআঁশ)',
    'Clay Loam (এঁটেল-দোআঁশ)',
    'Clay (এঁটেল)',
    'Sandy (বেলে)',
    'Silty (পলি মাটি)',
  ];

  final List<String> _quickFarmNames = [
    'উত্তর মাঠের জমি',
    'দক্ষিণ বিল ঘের',
    'বাড়ির পাশের বাগান',
    'পশ্চিম পাড়ার ক্ষেত',
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    _farmNameController.dispose();
    _farmSizeController.dispose();
    _locationController.dispose();
    _phController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveFarm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    try {
      final url = Uri.parse('http://localhost:5000/api/farms');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': _farmNameController.text.trim(),
          'landSize': _farmSizeController.text.trim(),
          'unit': _selectedUnit,
          'location': _locationController.text.trim(),
          'soilType': _selectedSoilType ?? 'Loamy (দোআঁশ)',
          'ph': _phController.text.trim().isNotEmpty ? _phController.text.trim() : null,
          'description': _descriptionController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ নতুন খামার সফলভাবে তৈরি হয়েছে!'),
            backgroundColor: Color(0xFF2f8d5c),
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(data['error'] ?? 'Failed to create farm');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'নতুন খামার / জমি যুক্ত করুন',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'খামারের সাধারণ তথ্য',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _quickFarmNames.map((name) {
                  return ActionChip(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    label: Text(name, style: const TextStyle(fontSize: 12, color: Color(0xFF18392d))),
                    onPressed: () => setState(() => _farmNameController.text = name),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _farmNameController,
                decoration: _buildInputDecoration('খামার বা জমির নাম *', Icons.landscape, 'যেমন: উত্তর মাঠের জমি'),
                validator: (value) => value == null || value.isEmpty ? 'খামারের নাম লিখুন' : null,
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _farmSizeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _buildInputDecoration('জমির আয়তন *', Icons.straighten, 'যেমন: ৫০'),
                      validator: (value) => value == null || value.isEmpty ? 'আয়তন দিন' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: _buildInputDecoration('একক', Icons.aspect_ratio, null),
                      items: _landUnits.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUnit = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _locationController,
                decoration: _buildInputDecoration('এলাকা / উপজেলা / জেলা *', Icons.location_on, 'যেমন: ডুমুরিয়া, খুলনা'),
                validator: (value) => value == null || value.isEmpty ? 'জমির লোকেশন লিখুন' : null,
              ),
              const SizedBox(height: 24),

              const Text(
                'মাটির গুণাগুণ (Soil Information)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
              ),
              const SizedBox(height: 14),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: DropdownButtonFormField<String>(
                      value: _selectedSoilType,
                      decoration: _buildInputDecoration('মাটির ধরন', Icons.grass, null),
                      items: _soilTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 12.5)));
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedSoilType = value),
                      validator: (value) => value == null ? 'মাটির ধরন বাছুন' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _phController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _buildInputDecoration('মাটির pH (ঐচ্ছিক)', Icons.science, 'যেমন: 6.5'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'জমির বিশেষ বিবরণ (ঐচ্ছিক)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'জমিতে জলাবদ্ধতা হয় কি না, সেচের সুবিধা কেমন ইত্যাদি লিখে রাখতে পারেন...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2f8d5c), width: 2)),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2f8d5c),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _isLoading ? null : _saveFarm,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('খামার সংরক্ষণ করুন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, String? hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      labelStyle: const TextStyle(color: Color(0xFF4d6e60), fontSize: 13.5),
      prefixIcon: Icon(icon, color: const Color(0xFF2f8d5c), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2f8d5c), width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
    );
  }
}