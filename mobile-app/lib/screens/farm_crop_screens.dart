import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/common_widgets.dart';
import 'crop_details_screen.dart';

// ফসলের ক্যাটাগরি, জনপ্রিয় ফসল এবং জাতের ডেটাবেস
const Map<String, Map<String, dynamic>> kCropCatalog = {
  'Vegetables': {
    'label': 'শাকসবজি (Vegetables)',
    'shortLabel': 'শাকসবজি',
    'emoji': '🥦',
    'color': Color(0xFF2f8d5c),
    'defaultSeedUnit': 'গ্রাম (gm)',
    'crops': [
      'আলু (Potato)',
      'টমেটো (Tomato)',
      'বেগুন (Brinjal)',
      'লাউ (Bottle Gourd)',
      'মিষ্টি কুমড়া (Pumpkin)',
      'ফুলকপি (Cauliflower)',
      'বাঁধাকপি (Cabbage)',
      'শসা (Cucumber)',
      'করলা (Bitter Gourd)',
      'ঢেঁড়স (Okra)',
      'লাল শাক (Red Amaranth)',
    ],
    'varieties': {
      'আলু (Potato)': ['ডায়মন্ড (Diamond)', 'কার্ডিনাল (Cardinal)', 'গ্র্যানোলা', 'দেশি লাল আলু'],
      'টমেটো (Tomato)': ['বারি টমেটো-১৪', 'বারি টমেটো-১৫', 'বাহুবলী (হাইব্রিড)', 'রতন'],
      'বেগুন (Brinjal)': ['বারি বেগুন-৮', 'উত্তরা', 'কাজলা', 'সিংগনাথ'],
      'লাউ (Bottle Gourd)': ['বারি লাউ-৪', 'ডায়না (হাইব্রিড)', 'ময়না'],
    },
  },
  'Fruits': {
    'label': 'ফলমূল (Fruits)',
    'shortLabel': 'ফলমূল',
    'emoji': '🍎',
    'color': Color(0xFFe11d48),
    'defaultSeedUnit': 'টি চারা (Saplings)',
    'crops': [
      'তরমুজ (Watermelon)',
      'আম (Mango)',
      'পেঁপে (Papaya)',
      'কলা (Banana)',
      'পেয়ারা (Guava)',
      'মাল্টা (Malta)',
      'কুল/বরই (Jujube)',
      'লিচু (Lychee)',
      'আনারস (Pineapple)',
      'ড্রাগন ফল (Dragon Fruit)',
    ],
    'varieties': {
      'তরমুজ (Watermelon)': ['ব্ল্যাক বেবি (Black Baby)', 'পাকিজা', 'সুগার কুইন', 'জাগুয়ার'],
      'আম (Mango)': ['আম্রপালি', 'হিমসাগর', 'বারি আম-৪', 'কাটিমন (বারোমাসি)'],
      'পেঁপে (Papaya)': ['রেড লেডি (Red Lady)', 'শাহী পেঁপে', 'টপ লেডি'],
      'পেয়ারা (Guava)': ['থাই পেয়ারা-৫', 'কাজী পেয়ারা', 'বারি পেয়ারা-২'],
      'মাল্টা (Malta)': ['বারি মাল্টা-১ (পয়সা মাল্টা)'],
    },
  },
  'Grains': {
    'label': 'দানা শস্য (Grains & Paddy)',
    'shortLabel': 'দানা শস্য',
    'emoji': '🌾',
    'color': Color(0xFFd97706),
    'defaultSeedUnit': 'কেজি (kg)',
    'crops': [
      'বোরো ধান (Boro Rice)',
      'আমন ধান (Aman Rice)',
      'আউশ ধান (Aus Rice)',
      'গম (Wheat)',
      'ভুট্টা (Maize)',
      'সরিষা (Mustard)',
      'মসুর ডাল (Lentil)',
      'মুগ ডাল (Mung Bean)',
      'সূর্যমুখী (Sunflower)',
    ],
    'varieties': {
      'বোরো ধান (Boro Rice)': ['ব্রি ধান২৮', 'ব্রি ধান২৯', 'ব্রি ধান৮৯', 'ব্রি ধান৯২', 'বিনা ধান২৫'],
      'আমন ধান (Aman Rice)': ['ব্রি ধান৪৯', 'ব্রি ধান৭৫', 'ব্রি ধান৮৭', 'স্বর্ণা'],
      'গম (Wheat)': ['বারি গম-৩০', 'বারি গম-৩২', 'বারি গম-৩৩'],
      'সরিষা (Mustard)': ['বারি সরিষা-১৪', 'বারি সরিষা-১৭', 'বিনা সরিষা-৯'],
    },
  },
  'Spices': {
    'label': 'মসলা জাতীয় (Spices)',
    'shortLabel': 'মসলা জাতীয়',
    'emoji': '🌶️',
    'color': Color(0xFFdc2626),
    'defaultSeedUnit': 'কেজি (kg)',
    'crops': [
      'কাঁচা মরিচ (Chili)',
      'পেঁয়াজ (Onion)',
      'রসুন (Garlic)',
      'আদা (Ginger)',
      'হলুদ (Turmeric)',
      'ধনিয়া (Coriander)',
      'কালোজিরা (Black Cumin)',
    ],
    'varieties': {
      'কাঁচা মরিচ (Chili)': ['বিজলী প্লাস', 'বগুড়ার মরিচ', 'বারি মরিচ-২', 'বিন্দু মরিচ'],
      'পেঁয়াজ (Onion)': ['তাহেরপুরী', 'বারি পেঁয়াজ-৪', 'বারি পেঁয়াজ-৫ (গ্রীষ্মকালীন)', 'ফরিদপুরী'],
      'রসুন (Garlic)': ['বারি রসুন-৩', 'ইটালিয়ান রসুন', 'নাটোরের এক কোয়া'],
    },
  },
  'Others': {
    'label': 'অন্যান্য (Others)',
    'shortLabel': 'অন্যান্য',
    'emoji': '🌱',
    'color': Color(0xFF4f46e5),
    'defaultSeedUnit': 'কেজি (kg)',
    'crops': [
      'পাট (Jute)',
      'আখ (Sugarcane)',
      'পান (Betel Leaf)',
      'চিনাবাদাম (Peanut)',
      'তিল (Sesame)',
      'নেপিয়ার ঘাস (Napier Grass)',
    ],
    'varieties': {
      'পাট (Jute)': ['তোষা পাট (O-9897)', 'দেশি পাট', 'রবি-১'],
    },
  },
};

// ক্যাটাগরির নাম বা কী (Key) থেকে মেটাডেটা বের করার হেল্পার
Map<String, dynamic>? findCategoryMeta(String categoryInput) {
  final trimmed = categoryInput.trim();
  if (kCropCatalog.containsKey(trimmed)) {
    return kCropCatalog[trimmed];
  }
  for (var entry in kCropCatalog.entries) {
    if (entry.value['label'] == trimmed || entry.value['shortLabel'] == trimmed) {
      return entry.value;
    }
  }
  return null;
}

// ==========================================
// REGISTER CROP SCREEN (COMPACT 2-BOX SMART DESIGN)
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

  // শুধুমাত্র ২টি মূল কন্ট্রোলার: ফসলের ধরন এবং ফসলের নাম
  final _categoryController = TextEditingController(text: 'শাকসবজি (Vegetables)');
  final _cropTypeController = TextEditingController();
  final _varietyController = TextEditingController();
  final _allocatedAreaController = TextEditingController();
  final _seedQuantityController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedFarmId;
  String? _selectedFarmName;
  String _selectedAreaUnit = 'শতাংশ (Decimal)';
  String _selectedSeedUnit = 'গ্রাম (gm)';
  String _selectedSeedSource = 'স্থানীয় অনুমোদিত ডিলার';
  String? _selectedCultivationMethod = 'Open Field (মাঠ)';

  // গ্লোবাল ক্যাটালগ (ডিফল্ট + অন্য কৃষকদের যোগ করা উপযুক্ত ফসলের ধরন ও নাম)
  Map<String, List<String>> _dynamicCatalog = {};

  List<dynamic> _userFarms = [];
  bool _isLoadingFarms = true;
  DateTime? _plantingDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  final List<String> _areaUnits = [
    'শতাংশ (Decimal)',
    'বিঘা (Bigha)',
    'একর (Acre)',
    'কাঠা (Katha)',
  ];

  final List<String> _seedUnits = [
    'গ্রাম (gm)',
    'কেজি (kg)',
    'টি চারা (Saplings)',
    'প্যাকেট (Packet)',
  ];

  final List<String> _seedSources = [
    'স্থানীয় অনুমোদিত ডিলার',
    'বিএডিসি (BADC) বীজ',
    'নিজের সংরক্ষিত বীজ',
    'সরকারি কৃষি অফিস / নার্সারি',
    'কোম্পানি হাইব্রিড প্যাকেট',
  ];

  final List<String> _cultivationMethods = [
    'Open Field (মাঠ)',
    'Mulching Method (মালচিং পদ্ধতি)',
    'Bed & Furrow (বেড ও নালা পদ্ধতি)',
    'Machan / Trellis (মাচা পদ্ধতি)',
    'Roof Garden (ছাদ বাগান)',
    'Greenhouse (পলিনেট হাউজ)',
    'Floating/Baira (ভাসমান চাষ)',
  ];

  @override
  void initState() {
    super.initState();
    _initDefaultCatalog();
    if (widget.preSelectedFarmId != null && widget.preSelectedFarmName != null) {
      _selectedFarmId = widget.preSelectedFarmId;
      _selectedFarmName = widget.preSelectedFarmName;
    }
    _fetchUserFarms();
    _fetchSharedCatalog();
  }

  void _initDefaultCatalog() {
    final Map<String, List<String>> base = {};
    kCropCatalog.forEach((key, val) {
      final label = val['label'] as String;
      base[label] = List<String>.from(val['crops'] as List);
    });
    _dynamicCatalog = base;
  }

  // সার্ভার থেকে সব কৃষকের শেয়ারড ক্যাটালগ লোড করা
  Future<void> _fetchSharedCatalog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/crops/catalog'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final Map<String, List<String>> merged = Map<String, List<String>>.from(
          _dynamicCatalog.map((k, v) => MapEntry(k, List<String>.from(v))),
        );

        data.forEach((rawCat, rawCrops) {
          final meta = findCategoryMeta(rawCat);
          final String displayCat = meta != null ? (meta['label'] as String) : rawCat.trim();
          if (displayCat.isEmpty) return;

          merged.putIfAbsent(displayCat, () => []);
          if (rawCrops is List) {
            for (var c in rawCrops) {
              final cropStr = c.toString().trim();
              if (cropStr.isNotEmpty && !merged[displayCat]!.contains(cropStr)) {
                merged[displayCat]!.add(cropStr);
              }
            }
          }
        });

        if (mounted) {
          setState(() => _dynamicCatalog = merged);
        }
      }
    } catch (e) {
      // অফলাইন থাকলে ডিফল্ট ক্যাটালগ কাজ করবে
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
        final data = jsonDecode(response.body) as List;
        if (mounted) {
          setState(() {
            _userFarms = data;
            _isLoadingFarms = false;
            if (_selectedFarmId != null) {
              final farm = _userFarms.firstWhere(
                (f) => f['_id'].toString() == _selectedFarmId,
                orElse: () => null,
              );
              if (farm != null) {
                _applyFarmDefaults(farm);
              }
            }
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingFarms = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFarms = false);
    }
  }

  void _applyFarmDefaults(dynamic farm) {
    final farmUnit = farm['unit']?.toString();
    if (farmUnit != null && _areaUnits.contains(farmUnit)) {
      _selectedAreaUnit = farmUnit;
    }
    if (_allocatedAreaController.text.isEmpty && farm['landSize'] != null) {
      _allocatedAreaController.text = farm['landSize'].toString();
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _cropTypeController.dispose();
    _varietyController.dispose();
    _allocatedAreaController.dispose();
    _seedQuantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectPlantingDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _plantingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _plantingDate = picked);
    }
  }

  void _onCategorySelectedFromList(String categoryLabel) {
    setState(() {
      _categoryController.text = categoryLabel;
      _cropTypeController.clear();
      _varietyController.clear();

      final meta = findCategoryMeta(categoryLabel);
      if (meta != null) {
        final defaultUnit = meta['defaultSeedUnit'] as String?;
        if (defaultUnit != null && _seedUnits.contains(defaultUnit)) {
          _selectedSeedUnit = defaultUnit;
        }
      }
    });
  }

  List<String> _getCropSuggestionsForCurrentCategory() {
    final catText = _categoryController.text.trim();
    if (_dynamicCatalog.containsKey(catText)) {
      return _dynamicCatalog[catText]!;
    }
    final meta = findCategoryMeta(catText);
    if (meta != null) {
      final label = meta['label'] as String;
      if (_dynamicCatalog.containsKey(label)) {
        return _dynamicCatalog[label]!;
      }
    }
    // নতুন কোনো ধরন লিখলে সব ফসলের সাজেশন অ্যাক্সেসযোগ্য থাকবে
    final Set<String> allCrops = {};
    for (var list in _dynamicCatalog.values) {
      allCrops.addAll(list);
    }
    return allCrops.toList();
  }

  List<String> _getVarietySuggestionsForCurrentCrop() {
    final cropName = _cropTypeController.text.trim();
    for (var entry in kCropCatalog.values) {
      final varietiesMap = entry['varieties'] as Map<String, dynamic>?;
      if (varietiesMap != null && varietiesMap.containsKey(cropName)) {
        return List<String>.from(varietiesMap[cropName] as List);
      }
    }
    return [];
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFarmId == null) {
      setState(() => _errorMessage = 'অনুগ্রহ করে একটি খামার নির্বাচন করুন');
      return;
    }

    final String finalCategory = _categoryController.text.trim();
    final String finalCropName = _cropTypeController.text.trim();

    if (finalCategory.isEmpty) {
      setState(() => _errorMessage = 'ফসলের ধরন নির্বাচন করুন বা লিখুন');
      return;
    }
    if (finalCropName.isEmpty) {
      setState(() => _errorMessage = 'ফসলের নাম নির্বাচন করুন বা লিখুন');
      return;
    }
    if (_plantingDate == null) {
      setState(() => _errorMessage = 'রোপণের তারিখ নির্বাচন করুন');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    final double allocatedArea = double.tryParse(_allocatedAreaController.text.trim()) ?? 0;
    final double seedQty = double.tryParse(_seedQuantityController.text.trim()) ?? 0;

    String compiledDescription = _descriptionController.text.trim();
    final List<String> metaTags = [];
    if (allocatedArea > 0) metaTags.add('জমি: $allocatedArea $_selectedAreaUnit');
    if (seedQty > 0) metaTags.add('বীজ/চারা: $seedQty $_selectedSeedUnit ($_selectedSeedSource)');
    if (metaTags.isNotEmpty) {
      final metaLine = metaTags.join(' | ');
      compiledDescription = compiledDescription.isEmpty ? metaLine : '$metaLine\n$compiledDescription';
    }

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/crops'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'farmId': _selectedFarmId,
          'cropCategory': finalCategory,
          'cropType': finalCropName,
          'variety': _varietyController.text.trim(),
          'allocatedArea': allocatedArea,
          'areaUnit': _selectedAreaUnit,
          'seedQuantity': seedQty,
          'seedUnit': _selectedSeedUnit,
          'seedSource': _selectedSeedSource,
          'cultivationMethod': _selectedCultivationMethod,
          'sowingDate': _plantingDate!.toIso8601String(),
          'description': compiledDescription,
        }),
      );

      if (response.statusCode == 201) {
        setState(() {
          _successMessage = 'ফসল সফলভাবে যুক্ত হয়েছে!';
          _isLoading = false;
        });

        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 800));
          Navigator.of(context).pop(true);
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'ফসল যুক্ত করতে সমস্যা হয়েছে');
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
    final List<String> categorySuggestions = _dynamicCatalog.keys.toList();
    final List<String> cropSuggestions = _getCropSuggestionsForCurrentCategory();
    final List<String> varietySuggestions = _getVarietySuggestionsForCurrentCrop();

    Map<String, dynamic>? selectedFarmObj;
    if (_selectedFarmId != null && _userFarms.isNotEmpty) {
      selectedFarmObj = _userFarms.firstWhere(
        (f) => f['_id'].toString() == _selectedFarmId,
        orElse: () => null,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        title: Text(
          isFarmPreSelected ? '$_selectedFarmName-এ নতুন ফসল যোগ' : 'নতুন ফসল নিবন্ধন করুন',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // ১. খামার নির্বাচন
              // ==========================================
              if (!isFarmPreSelected) ...[
                _buildSectionHeader('১. খামার নির্বাচন করুন', Icons.landscape),
                const SizedBox(height: 10),
                _isLoadingFarms
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        value: _selectedFarmId,
                        decoration: _buildInputDecoration('খামার বেছে নিন *', Icons.agriculture, 'কোন জমিতে চাষ করবেন?'),
                        items: _userFarms.map<DropdownMenuItem<String>>((farm) {
                          final size = farm['landSize'] ?? '';
                          final unit = farm['unit'] ?? 'Acres';
                          return DropdownMenuItem<String>(
                            value: farm['_id'].toString(),
                            child: Text('${farm['name']} ($size $unit)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedFarmId = val;
                            final farm = _userFarms.firstWhere((f) => f['_id'].toString() == val, orElse: () => null);
                            if (farm != null) _applyFarmDefaults(farm);
                          });
                        },
                        validator: (val) => val == null ? 'অনুগ্রহ করে খামার নির্বাচন করুন' : null,
                      ),
                const SizedBox(height: 14),
              ],

              if (selectedFarmObj != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFedf9f1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFbce3c8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF2f8d5c), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'মোট জমি: ${selectedFarmObj['landSize']} ${selectedFarmObj['unit'] ?? 'একর'} • মাটি: ${selectedFarmObj['soilType'] ?? 'দোআঁশ'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF18392d)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // ==========================================
              // ২. ফসলের ধরন ও নাম (শুধুমাত্র ২টি স্মার্ট বক্স + জাত)
              // ==========================================
              _buildSectionHeader('২. ফসলের ধরন ও নাম', Icons.eco),
              const SizedBox(height: 10),

              // বক্স ১: ফসলের ধরন (ড্রপডাউন থেকে সিলেক্ট অথবা সরাসরি টাইপ)
              TextFormField(
                controller: _categoryController,
                onChanged: (_) => setState(() {}),
                decoration: _buildInputDecoration(
                  'ফসলের ধরন *',
                  Icons.category,
                  'তালিকা থেকে বাছুন অথবা নতুন ধরন লিখুন',
                ).copyWith(
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF2f8d5c)),
                    tooltip: 'ফসলের ধরন বাছুন',
                    onSelected: _onCategorySelectedFromList,
                    itemBuilder: (context) => categorySuggestions.map((catLabel) {
                      final meta = findCategoryMeta(catLabel);
                      final emoji = meta != null ? (meta['emoji'] as String) : '🌱';
                      return PopupMenuItem<String>(
                        value: catLabel,
                        child: Row(
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(catLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'ফসলের ধরন নির্বাচন করুন বা লিখুন' : null,
              ),
              const SizedBox(height: 12),

              // বক্স ২: ফসলের নাম (ড্রপডাউন থেকে সিলেক্ট অথবা সরাসরি টাইপ)
              TextFormField(
                controller: _cropTypeController,
                onChanged: (_) => setState(() {}),
                decoration: _buildInputDecoration(
                  'ফসলের নাম *',
                  Icons.grass,
                  'তালিকা থেকে বাছুন অথবা ফসলের নাম লিখুন',
                ).copyWith(
                  suffixIcon: cropSuggestions.isNotEmpty
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF2f8d5c)),
                          tooltip: 'তালিকা থেকে ফসল বাছুন',
                          onSelected: (String val) {
                            setState(() {
                              _cropTypeController.text = val;
                              _varietyController.clear();
                            });
                          },
                          itemBuilder: (context) => cropSuggestions
                              .map((cropName) => PopupMenuItem<String>(
                                    value: cropName,
                                    child: Text(cropName, style: const TextStyle(fontSize: 14)),
                                  ))
                              .toList(),
                        )
                      : null,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'ফসলের নাম নির্বাচন করুন বা লিখুন' : null,
              ),
              const SizedBox(height: 12),

              // ফসলের জাত (ঐচ্ছিক)
              TextFormField(
                controller: _varietyController,
                decoration: _buildInputDecoration(
                  'ফসলের জাত / হাইব্রিড নাম (ঐচ্ছিক)',
                  Icons.local_florist,
                  varietySuggestions.isNotEmpty
                      ? 'লিখুন অথবা ডানপাশের তালিকা থেকে বাছুন'
                      : 'যেমন: ডায়মন্ড আলু, ব্রি ধান২৮, বারি-১৪',
                ).copyWith(
                  suffixIcon: varietySuggestions.isNotEmpty
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF2f8d5c)),
                          tooltip: 'জনপ্রিয় জাতের তালিকা দেখুন',
                          onSelected: (String val) {
                            setState(() => _varietyController.text = val);
                          },
                          itemBuilder: (context) => varietySuggestions
                              .map((v) => PopupMenuItem<String>(
                                    value: v,
                                    child: Text(v, style: const TextStyle(fontSize: 13.5)),
                                  ))
                              .toList(),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // ৩. আবাদকৃত জমির পরিমাণ
              // ==========================================
              _buildSectionHeader('৩. আবাদকৃত জমির পরিমাণ', Icons.straighten),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _allocatedAreaController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _buildInputDecoration('জমির পরিমাণ *', Icons.square_foot, 'যেমন: ৩০'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'জমির পরিমাণ দিন' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: DropdownButtonFormField<String>(
                      value: _selectedAreaUnit,
                      decoration: _buildInputDecoration('একক', Icons.aspect_ratio, ''),
                      items: _areaUnits.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedAreaUnit = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ==========================================
              // ৪. বীজ বা চারার বিবরণ
              // ==========================================
              _buildSectionHeader('৪. বীজ বা চারার বিবরণ', Icons.spa),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _seedQuantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _buildInputDecoration('পরিমাণ (ঐচ্ছিক)', Icons.scale, 'যেমন: ২.৫ বা ২০০'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: DropdownButtonFormField<String>(
                      value: _selectedSeedUnit,
                      decoration: _buildInputDecoration('একক', Icons.inventory_2_outlined, ''),
                      items: _seedUnits.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSeedUnit = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedSeedSource,
                decoration: _buildInputDecoration('বীজ বা চারার উৎস', Icons.storefront, 'কোথা থেকে সংগ্রহ করেছেন?'),
                items: _seedSources.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13.5)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSeedSource = val);
                },
              ),
              const SizedBox(height: 20),

              // ==========================================
              // ৫. চাষের পদ্ধতি ও রোপণের তারিখ
              // ==========================================
              _buildSectionHeader('৫. চাষের পদ্ধতি ও রোপণের তারিখ', Icons.calendar_month),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCultivationMethod,
                decoration: _buildInputDecoration('চাষাবাদ পদ্ধতি', Icons.terrain, 'পদ্ধতি নির্বাচন করুন'),
                items: _cultivationMethods.map((method) => DropdownMenuItem(value: method, child: Text(method, style: const TextStyle(fontSize: 13.5)))).toList(),
                onChanged: (val) => setState(() => _selectedCultivationMethod = val),
                validator: (val) => val == null ? 'চাষ পদ্ধতি নির্বাচন করুন' : null,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _selectPlantingDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Color(0xFF2f8d5c)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _plantingDate == null
                              ? 'রোপণ বা বীজ বপনের তারিখ নির্বাচন করুন'
                              : 'রোপণের তারিখ: ${_plantingDate!.year}-${_plantingDate!.month.toString().padLeft(2, '0')}-${_plantingDate!.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Color(0xFF18392d), fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Text('পরিবর্তন', style: TextStyle(color: Color(0xFF2f8d5c), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // ৬. অতিরিক্ত নোট
              // ==========================================
              _buildSectionHeader('৬. বিশেষ কোনো তথ্য বা নোট (ঐচ্ছিক)', Icons.edit_note),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'যেমন: জমিতে আগে কী ফসল ছিল বা বিশেষ কোনো নোট...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              if (_errorMessage != null) ...[
                StatusAlert(message: _errorMessage!, isError: true, isVisible: true),
                const SizedBox(height: 14),
              ],
              if (_successMessage != null) ...[
                StatusAlert(message: _successMessage!, isError: false, isVisible: true),
                const SizedBox(height: 14),
              ],
              SmartFarmerButton(
                label: _isLoading ? 'ফসল যুক্ত হচ্ছে...' : 'ফসল নিবন্ধন সম্পন্ন করুন',
                onPressed: _handleSubmit,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2f8d5c)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12.5),
      prefixIcon: Icon(icon, color: const Color(0xFF2f8d5c), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}

// =========================================================
// FARM DETAILS SCREEN (PROFESSIONAL SUMMARY + CROPS LIST)
// =========================================================
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
  String _displayFarmName = '';
  Map<String, dynamic>? _farmDetails;

  @override
  void initState() {
    super.initState();
    _displayFarmName = widget.farmName;
    _fetchFarmDataAndCrops();
  }

  Future<void> _fetchFarmDataAndCrops() async {
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

      final farmRes = await http.get(
        Uri.parse('http://localhost:5000/api/farms/my-farms'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && farmRes.statusCode == 200) {
        final allCrops = jsonDecode(response.body) as List;
        final allFarms = jsonDecode(farmRes.body) as List;

        final filteredCrops = allCrops.where((crop) {
          final farmObj = crop['farmId'];
          if (farmObj is Map) {
            return farmObj['_id'] == widget.farmId;
          }
          return farmObj == widget.farmId;
        }).toList();

        final currentFarm = allFarms.firstWhere(
          (f) => f['_id'] == widget.farmId,
          orElse: () => null,
        );

        if (mounted) {
          setState(() {
            _farmCrops = filteredCrops;
            if (currentFarm != null) {
              _farmDetails = currentFarm;
              _displayFarmName = currentFarm['name'] ?? widget.farmName;
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFarm() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ফার্ম মুছুন', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('আপনি কি নিশ্চিত যে এই ফার্মটি মুছে ফেলতে চান? এর সাথে যুক্ত সব ফসল এবং কাজ চিরতরে মুছে যাবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('না, বাতিল', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('হ্যাঁ, মুছুন', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final res = await http.delete(
        Uri.parse('http://localhost:5000/api/farms/${widget.farmId}'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ফার্মটি সফলভাবে মুছে ফেলা হয়েছে!'), backgroundColor: Colors.red),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditFarmModal() {
    final nameController = TextEditingController(text: _farmDetails?['name'] ?? '');
    final locationController = TextEditingController(text: _farmDetails?['location'] ?? '');
    final sizeController = TextEditingController(text: (_farmDetails?['landSize'] ?? '').toString());
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ফার্ম সম্পাদনা করুন (Edit Farm)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'খামারের নাম', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sizeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'জমির আয়তন', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(labelText: 'এলাকা / জেলা', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: isSaving ? null : () async {
                        if (nameController.text.trim().isEmpty) return;
                        setModalState(() => isSaving = true);
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);

                        try {
                          final res = await http.put(
                            Uri.parse('http://localhost:5000/api/farms/${widget.farmId}'),
                            headers: {
                              'Content-Type': 'application/json',
                              'Authorization': 'Bearer ${authProvider.token}'
                            },
                            body: jsonEncode({
                              'name': nameController.text.trim(),
                              'location': locationController.text.trim(),
                              'landSize': double.tryParse(sizeController.text.trim()) ?? _farmDetails?['landSize'],
                              'soilType': _farmDetails?['soilType'],
                              'ph': _farmDetails?['ph'],
                            }),
                          );
                          if (res.statusCode == 200) {
                            if (mounted) Navigator.pop(modalContext);
                            _fetchFarmDataAndCrops();
                          }
                        } catch (e) {
                          setModalState(() => isSaving = false);
                        }
                      },
                      child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('আপডেট করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double totalFarmExpense = _farmCrops.fold(0.0, (sum, c) => sum + ((c['totalExpense'] ?? 0).toDouble()));

    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        title: Text(_displayFarmName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF12362b),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.white70), tooltip: 'Edit Farm', onPressed: _showEditFarmModal),
          IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), tooltip: 'Delete Farm', onPressed: _deleteFarm),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_farmDetails != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF18392d), Color(0xFF2f8d5c)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _farmDetails!['location'] ?? 'লোকেশন দেওয়া নেই',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            'মোট খরচ: ৳${totalFarmExpense.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFarmStat('মোট জমি', '${_farmDetails!['landSize'] ?? 0} ${_farmDetails!['unit'] ?? 'একর'}'),
                        _buildFarmStat('মাটির ধরন', '${_farmDetails!['soilType'] ?? 'দোআঁশ'}'),
                        _buildFarmStat('মাটির pH', '${_farmDetails!['ph'] ?? 'স্বাভাবিক'}'),
                        _buildFarmStat('চলমান ফসল', '${_farmCrops.length}টি'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'এই খামারের ফসলসমূহ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2f8d5c),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RegisterCropScreen(
                          preSelectedFarmId: widget.farmId,
                          preSelectedFarmName: _displayFarmName,
                        ),
                      ),
                    );
                    if (result == true) {
                      _fetchFarmDataAndCrops();
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('নতুন ফসল যোগ'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2f8d5c)))
                  : _farmCrops.isEmpty
                      ? const Center(
                          child: Text(
                            'এই খামারে এখনো কোনো ফসল যুক্ত করা হয়নি।\nউপরের "নতুন ফসল যোগ" বাটনে ক্লিক করে শুরু করুন।',
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
                            final stage = crop['currentStage'] ?? 'Germination';
                            final categoryKey = crop['cropCategory']?.toString() ?? 'Vegetables';
                            final catMeta = findCategoryMeta(categoryKey);
                            final String emoji = catMeta != null ? (catMeta['emoji'] as String) : '🌱';
                            final allocatedArea = (crop['allocatedArea'] ?? 0).toDouble();
                            final areaUnit = crop['areaUnit'] ?? 'শতাংশ';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 1.5,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFFedf9f1),
                                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                                ),
                                title: Text(
                                  '$cropType ${variety.isNotEmpty ? '($variety)' : ''}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Color(0xFF18392d)),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ধাপ: $stage • ধরন: ${catMeta != null ? catMeta['shortLabel'] : categoryKey}',
                                        style: const TextStyle(fontSize: 12.5),
                                      ),
                                      if (allocatedArea > 0)
                                        Text(
                                          'জমি: $allocatedArea $areaUnit • খরচ: ৳${crop['totalExpense'] ?? 0}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF2f8d5c), fontWeight: FontWeight.w600),
                                        ),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CropDetailsScreen(
                                        cropId: crop['_id'].toString(),
                                        itemName: cropType,
                                      ),
                                    ),
                                  ).then((_) => _fetchFarmDataAndCrops());
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

  Widget _buildFarmStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}