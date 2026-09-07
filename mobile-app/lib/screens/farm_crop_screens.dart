import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/common_widgets.dart';
import 'crop_details_screen.dart';

// ==========================================
// REGISTER CROP SCREEN (আগের মতোই থাকবে)
// ==========================================
class RegisterCropScreen extends StatefulWidget {
  final String? preSelectedFarmId;
  final String? preSelectedFarmName;

  const RegisterCropScreen({
    super.key,
    this.preSelectedFarmId,
    this.preSelectedFarmName,
  });

  @override
  State<RegisterCropScreen> createState() => _RegisterCropScreenState();
}

class _RegisterCropScreenState extends State<RegisterCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cropTypeController = TextEditingController();
  final _varietyController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedFarmId;
  String? _selectedFarmName;
  String? _selectedCultivationMethod = 'Open Field (মাঠ)';

  List<dynamic> _userFarms = [];
  bool _isLoadingFarms = true;
  DateTime? _plantingDate;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  final List<String> _cultivationMethods = [
    'Open Field (মাঠ)',
    'Roof Garden (ছাদ বাগান)',
    'Greenhouse (পলিনেট হাউজ)',
    'Floating/Baira (ভাসমান চাষ)',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedFarmId != null &&
        widget.preSelectedFarmName != null) {
      _selectedFarmId = widget.preSelectedFarmId;
      _selectedFarmName = widget.preSelectedFarmName;
      _isLoadingFarms = false;
    } else {
      _fetchUserFarms();
    }
  }

  Future<void> _fetchUserFarms() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/farms/my-farms'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userFarms = data;
          _isLoadingFarms = false;
        });
      } else {
        setState(() => _isLoadingFarms = false);
      }
    } catch (e) {
      setState(() => _isLoadingFarms = false);
    }
  }

  @override
  void dispose() {
    _cropTypeController.dispose();
    _varietyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectPlantingDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _plantingDate = picked);
    }
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFarmId == null) {
      setState(() => _errorMessage = 'Please select a farm');
      return;
    }
    if (_plantingDate == null) {
      setState(() => _errorMessage = 'Please select a planting date');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/crops'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'farmId': _selectedFarmId,
          'cropType': _cropTypeController.text.trim(),
          'variety': _varietyController.text.trim(),
          'cultivationMethod': _selectedCultivationMethod,
          'sowingDate': _plantingDate!.toIso8601String(),
          'description': _descriptionController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        setState(() {
          _successMessage = 'Crop registered successfully!';
          _isLoading = false;
        });

        if (mounted) {
          await Future.delayed(const Duration(seconds: 1));
          Navigator.of(context).pop(true);
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to register crop');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isFarmPreSelected = widget.preSelectedFarmId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        title: Text(
          isFarmPreSelected
              ? 'Add Crop to $_selectedFarmName'
              : 'Register New Crop',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isFarmPreSelected) ...[
                const Text(
                  'Select Farm',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18392d),
                  ),
                ),
                const SizedBox(height: 8),
                _isLoadingFarms
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedFarmId,
                        decoration: _buildInputDecoration(
                          'Choose Farm',
                          Icons.agriculture,
                          'Select farm location',
                        ),
                        items: _userFarms.map<DropdownMenuItem<String>>((farm) {
                          return DropdownMenuItem<String>(
                            value: farm['_id'].toString(),
                            child: Text(farm['name']),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedFarmId = val),
                        validator: (val) =>
                            val == null ? 'Please select a farm' : null,
                      ),
                const SizedBox(height: 20),
              ],
              const Text(
                'Crop Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18392d),
                ),
              ),
              const SizedBox(height: 12),
              SmartFarmerInputField(
                label: 'Crop Type',
                placeholder: 'e.g., Rice, Potato, Tomato',
                controller: _cropTypeController,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Crop type is required'
                    : null,
              ),
              const SizedBox(height: 16),
              SmartFarmerInputField(
                label: 'Variety (Optional)',
                placeholder: 'e.g., BRRI dhan28, Binasail',
                controller: _varietyController,
              ),
              const SizedBox(height: 20),
              const Text(
                'Cultivation & Timeline',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18392d),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCultivationMethod,
                decoration: _buildInputDecoration(
                  'Cultivation Method',
                  Icons.grass,
                  'Select method',
                ),
                items: _cultivationMethods
                    .map(
                      (method) =>
                          DropdownMenuItem(value: method, child: Text(method)),
                    )
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedCultivationMethod = val),
                validator: (val) => val == null ? 'Please select method' : null,
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Planting Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF214e3d),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selectPlantingDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Color(0xFF2f8d5c),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _plantingDate == null
                                  ? 'Select planting date'
                                  : '${_plantingDate!.year}-${_plantingDate!.month.toString().padLeft(2, '0')}-${_plantingDate!.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: _plantingDate == null
                                    ? Colors.grey
                                    : const Color(0xFF18392d),
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Additional Notes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18392d),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Any specific note or pre-existing issues...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                StatusAlert(
                  message: _errorMessage!,
                  isError: true,
                  isVisible: true,
                ),
                const SizedBox(height: 16),
              ],
              if (_successMessage != null) ...[
                StatusAlert(
                  message: _successMessage!,
                  isError: false,
                  isVisible: true,
                ),
                const SizedBox(height: 16),
              ],
              SmartFarmerButton(
                label: _isLoading ? 'Registering Crop...' : 'Register Crop',
                onPressed: _handleSubmit,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon,
    String hint,
  ) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF2f8d5c), size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}

// ==========================================
// FARM DETAILS SCREEN (DATABASE CONNECTED CROPS)
// ==========================================
class FarmDetailsScreen extends StatefulWidget {
  final String farmId;
  final String farmName;

  const FarmDetailsScreen({
    super.key,
    required this.farmId,
    required this.farmName,
  });

  @override
  State<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  List<dynamic> _farmCrops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCropsForThisFarm();
  }

  Future<void> _fetchCropsForThisFarm() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/crops/my'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final allCrops = jsonDecode(response.body) as List;
        // শুধুমাত্র এই ফার্মের আন্ডারের ক্রপগুলো ফিল্টার করা
        final filteredCrops = allCrops.where((crop) {
          final farmObj = crop['farmId'];
          if (farmObj is Map) {
            return farmObj['_id'] == widget.farmId;
          }
          return farmObj == widget.farmId;
        }).toList();

        setState(() {
          _farmCrops = filteredCrops;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        title: Text(
          widget.farmName,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF12362b),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Crops in this Farm',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18392d),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2f8d5c),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RegisterCropScreen(
                          preSelectedFarmId: widget.farmId,
                          preSelectedFarmName: widget.farmName,
                        ),
                      ),
                    );
                    if (result == true) {
                      _fetchCropsForThisFarm(); // নতুন ক্রপ যোগ করে আসলে লিস্ট রিফ্রেশ হবে
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Crop'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2f8d5c),
                      ),
                    )
                  : _farmCrops.isEmpty
                  ? const Center(
                      child: Text(
                        'No crops added to this farm yet.\nClick "Add Crop" to start.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _farmCrops.length,
                      itemBuilder: (context, index) {
                        final crop = _farmCrops[index];
                        final cropType = crop['cropType'] ?? 'Crop';
                        final variety = crop['variety'] ?? '';
                        final stage = crop['currentStage'] ?? 'Initial';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFedf9f1),
                              child: Icon(Icons.eco, color: Color(0xFF2f8d5c)),
                            ),
                            title: Text(
                              '$cropType ${variety.isNotEmpty ? '($variety)' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Stage: $stage • Method: ${crop['cultivationMethod'] ?? 'N/A'}',
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CropDetailsScreen(
                                    cropId: crop['_id']
                                        .toString(), // ডেটাবেসের ক্রপ আইডি
                                    itemName: cropType,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
