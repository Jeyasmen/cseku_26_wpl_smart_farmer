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

  // Controllers for text fields
  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _farmSizeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedSoilType;
  final List<String> _soilTypes = [
    'Loamy (দোআঁশ)',
    'Clay (এঁটেল)',
    'Sandy (বেলে)',
    'Silty (পলি)',
    'Peaty (জৈব)'
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

  // 🚀 REAL BACKEND CALL TO SAVE FARM IN MONGODB
  Future<void> _saveFarm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token; // ✅ সঠিক প্রপার্টি
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
            content: Text('Farm created successfully and saved in Database!'),
            backgroundColor: Color(0xFF2f8d5c),
          ),
        );
        Navigator.pop(context, true); // Go back to Dashboard
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
        setState(() {
          _isLoading = false;
        });
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
          'Add New Farm',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                'Farm Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
              ),
              const SizedBox(height: 16),

              // 1. Farm Name
              TextFormField(
                controller: _farmNameController,
                decoration: _buildInputDecoration('Farm Name', Icons.landscape, 'e.g., North Field'),
                validator: (value) => value == null || value.isEmpty ? 'Please enter farm name' : null,
              ),
              const SizedBox(height: 16),

              // 2. Farm Size & Location (Row)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _farmSizeController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration('Size (Acres)', Icons.straighten, 'e.g., 2.5'),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _locationController,
                      decoration: _buildInputDecoration('Location', Icons.location_on, 'e.g., Sonapur'),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Soil Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
              ),
              const SizedBox(height: 16),

              // 3. Soil Type & Soil pH
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedSoilType,
                      decoration: _buildInputDecoration('Soil Type', Icons.grass, null),
                      items: _soilTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSoilType = value;
                        });
                      },
                      validator: (value) => value == null ? 'Select type' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _phController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration('Soil pH (Opt)', Icons.science, 'e.g., 6.5'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Additional Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
              ),
              const SizedBox(height: 16),

              // 4. Description Box
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Any specific issues like waterlogging, previous crop diseases, etc. This helps our AI give better advice.',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2f8d5c), width: 2)),
                ),
              ),
              const SizedBox(height: 32),

              // 5. Submit Button
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
                      : const Text('Create Farm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      labelStyle: const TextStyle(color: Color(0xFF4d6e60), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF2f8d5c), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2f8d5c), width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
    );
  }
}