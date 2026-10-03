import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../providers/auth_provider.dart';

const Map<String, Map<String, dynamic>> kExpenseCategories = {
  'Fertilizer': {
    'label': 'সার (Fertilizer)',
    'shortLabel': 'সার',
    'color': Color(0xFF2f8d5c),
    'icon': Icons.grass,
  },
  'Labor': {
    'label': 'শ্রমিক ও মজুরি (Labor)',
    'shortLabel': 'শ্রমিক/মজুরি',
    'color': Color(0xFFf59e0b),
    'icon': Icons.groups,
  },
  'Pesticide': {
    'label': 'কীটনাশক ও ওষুধ (Pesticide)',
    'shortLabel': 'কীটনাশক',
    'color': Color(0xFFef4444),
    'icon': Icons.bug_report,
  },
  'Seeds': {
    'label': 'বীজ ও চারা (Seeds)',
    'shortLabel': 'বীজ/চারা',
    'color': Color(0xFF8b5cf6),
    'icon': Icons.spa,
  },
  'Irrigation': {
    'label': 'সেচ ও পানি (Irrigation)',
    'shortLabel': 'সেচ',
    'color': Color(0xFF3b82f6),
    'icon': Icons.water_drop,
  },
  'Other': {
    'label': 'অন্যান্য খরচ',
    'shortLabel': 'অন্যান্য',
    'color': Color(0xFF64748b),
    'icon': Icons.receipt_long,
  },
};

const List<Color> _customPalette = [
  Color(0xFF0d9488),
  Color(0xFFe11d48),
  Color(0xFF4f46e5),
  Color(0xFFd97706),
  Color(0xFF0284c7),
  Color(0xFF7c3aed),
];

Map<String, dynamic> getCategoryMeta(String categoryKey) {
  if (kExpenseCategories.containsKey(categoryKey)) {
    return kExpenseCategories[categoryKey]!;
  }
  final int hash = categoryKey.codeUnits.fold(0, (a, b) => a + b);
  final Color color = _customPalette[hash % _customPalette.length];
  return {
    'label': categoryKey,
    'shortLabel': categoryKey,
    'color': color,
    'icon': Icons.category,
  };
}

class SmartBengaliSpeaker {
  html.AudioElement? _audioElement;
  bool _isSpeaking = false;

  String _toBengaliDigits(String input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String out = input;
    for (int i = 0; i < 10; i++) {
      out = out.replaceAll(en[i], bn[i]);
    }
    return out;
  }

  List<String> _splitIntoChunks(String text) {
    final List<String> chunks = [];
    final sentences = text.split(RegExp(r'(?<=[।.!?\n])'));
    String current = '';

    for (var s in sentences) {
      final trimmed = s.trim();
      if (trimmed.isEmpty) continue;
      if ((current.length + trimmed.length) < 160) {
        current = current.isEmpty ? trimmed : '$current $trimmed';
      } else {
        if (current.isNotEmpty) chunks.add(current);
        if (trimmed.length <= 160) {
          current = trimmed;
        } else {
          final words = trimmed.split(' ');
          String temp = '';
          for (var w in words) {
            if ((temp.length + w.length) < 150) {
              temp = temp.isEmpty ? w : '$temp $w';
            } else {
              if (temp.isNotEmpty) chunks.add(temp);
              temp = w;
            }
          }
          current = temp;
        }
      }
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  Future<void> speak(String rawText, {VoidCallback? onStart, VoidCallback? onComplete}) async {
    if (_isSpeaking) {
      await stop();
      if (onComplete != null) onComplete();
      return;
    }

    String cleanText = rawText
        .replaceAll(RegExp(r'[\*\#\_\`\~•]'), ' ')
        .replaceAll(RegExp(r'\([A-Za-z\s\/]+\)'), '')
        .replaceAll(RegExp(r'\bAI\b', caseSensitive: false), 'কৃষি বিশেষজ্ঞ')
        .replaceAll('%', ' শতাংশ ')
        .replaceAll('৳', ' টাকা ')
        .replaceAll('Tk', ' টাকা ');

    cleanText = _toBengaliDigits(cleanText).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanText.isEmpty) return;

    _isSpeaking = true;
    if (onStart != null) onStart();

    final chunks = _splitIntoChunks(cleanText);

    try {
      for (final chunk in chunks) {
        if (!_isSpeaking) break;
        await _playChunk(chunk);
      }
    } catch (e) {
      debugPrint('Audio playback error: $e');
    } finally {
      _isSpeaking = false;
      if (onComplete != null) onComplete();
    }
  }

  Future<void> _playChunk(String chunk) async {
    final completer = Completer<void>();
    final url = 'http://localhost:5000/api/tts?text=${Uri.encodeComponent(chunk)}';

    _audioElement?.pause();
    _audioElement = html.AudioElement(url);

    _audioElement!.onEnded.first.then((_) {
      if (!completer.isCompleted) completer.complete();
    });

    _audioElement!.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete();
    });

    try {
      await _audioElement!.play();
    } catch (e) {
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future;
  }

  Future<void> stop() async {
    _isSpeaking = false;
    _audioElement?.pause();
    _audioElement = null;
  }
}

class CropDetailsScreen extends StatefulWidget {
  final String cropId;
  final String itemName;

  const CropDetailsScreen({
    super.key,
    required this.cropId,
    required this.itemName,
  });

  @override
  State<CropDetailsScreen> createState() => _CropDetailsScreenState();
}

class _CropDetailsScreenState extends State<CropDetailsScreen> {
  bool _isLoading = true;
  bool _isOptimizing = false;
  Map<String, dynamic>? _cropData;
  double _totalExpense = 0.0;
  int _cropAgeDays = 0;
  String _currentStage = '';
  String _displayItemName = '';
  String _aiExpenseAnalysis = '';

  List<dynamic> _todaysTasks = [];
  List<dynamic> _upcomingTasks = [];
  List<dynamic> _laterTasks = [];
  List<dynamic> _expenses = [];
  List<dynamic> _notes = [];
  List<dynamic> _cropIssues = [];

  final SmartBengaliSpeaker _speaker = SmartBengaliSpeaker();

  @override
  void initState() {
    super.initState();
    _displayItemName = widget.itemName;
    _fetchCropDetails();
    _fetchCropIssues();
  }

  @override
  void dispose() {
    _speaker.stop();
    super.dispose();
  }

  Future<void> _fetchCropDetails() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    try {
      final response = await http
          .get(
            Uri.parse('http://localhost:5000/api/crops/${widget.cropId}/details'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final crop = data['crop'] ?? {};
        List<dynamic> tasks = (data['tasks'] as List?) ?? [];

        final sowingDate = DateTime.tryParse(crop['sowingDate']?.toString() ?? '') ?? DateTime.now();
        final now = DateTime.now();
        final age = now.difference(sowingDate).inDays;

        tasks.sort((a, b) {
          final dateA = DateTime.tryParse(a['scheduledDate']?.toString() ?? '') ?? now;
          final dateB = DateTime.tryParse(b['scheduledDate']?.toString() ?? '') ?? now;
          return dateA.compareTo(dateB);
        });

        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final dayAfterTomorrow = today.add(const Duration(days: 2));

        List<dynamic> todayTasksList = [];
        List<dynamic> upcomingTasksList = [];
        List<dynamic> laterTasksList = [];

        for (var task in tasks) {
          final taskDateTime = DateTime.tryParse(task['scheduledDate']?.toString() ?? '') ?? now;
          final taskDate = DateTime(taskDateTime.year, taskDateTime.month, taskDateTime.day);
          final isCompleted = task['status'] == 'Completed';

          if (taskDate.isBefore(today)) {
            if (!isCompleted) {
              task['isOverdue'] = true;
              todayTasksList.add(task);
            }
          } else if (taskDate.isAtSameMomentAs(today)) {
            todayTasksList.add(task);
          } else if (taskDate.isAtSameMomentAs(tomorrow) || taskDate.isAtSameMomentAs(dayAfterTomorrow)) {
            upcomingTasksList.add(task);
          } else if (taskDate.isAfter(dayAfterTomorrow)) {
            laterTasksList.add(task);
          }
        }

        if (upcomingTasksList.length > 5) {
          laterTasksList.insertAll(0, upcomingTasksList.sublist(5));
          upcomingTasksList = upcomingTasksList.sublist(0, 5);
        }

        if (mounted) {
          setState(() {
            _cropData = crop;
            _displayItemName = crop['cropType']?.toString() ?? widget.itemName;
            _totalExpense = (crop['totalExpense'] ?? 0).toDouble();
            _expenses = crop['expenses'] ?? [];
            _notes = crop['diaryNotes'] ?? [];
            _cropAgeDays = age >= 0 ? age : 0;

            final String savedStage = crop['currentStage']?.toString() ?? '';
            final String savedStatus = crop['status']?.toString() ?? '';
            if (savedStage.contains('Harvested') || savedStatus == 'Harvested') {
              _currentStage = 'ফসল তোলা সম্পন্ন (Harvested)';
            } else {
              _currentStage = savedStage.isNotEmpty ? savedStage : 'বৃদ্ধির ধাপ (Growing)';
            }

            _aiExpenseAnalysis = crop['aiExpenseAnalysis']?.toString() ?? '';
            _todaysTasks = todayTasksList;
            _upcomingTasks = upcomingTasksList;
            _laterTasks = laterTasksList;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading crop details: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchCropIssues() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse('http://localhost:5000/api/crops/${widget.cropId}/issues'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _cropIssues = jsonDecode(res.body)['issues'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching issues: $e');
    }
  }

  Future<void> _harvestCrop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ফসল কর্তন ও হিসাব মূল্যায়ন', style: TextStyle(color: Color(0xFF18392d), fontWeight: FontWeight.bold)),
        content: const Text('আপনি কি ফসল ঘরে তুলেছেন? এটি নিশ্চিত করলে আপনার পুরো মৌসুমের খরচের হিসাব মূল্যায়ন করে আগামী মৌসুমে খরচ কমানোর পরামর্শ তৈরি করা হবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('এখন নয়', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('হ্যাঁ, ফসল তোলা সম্পন্ন'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final res = await http.put(
        Uri.parse('http://localhost:5000/api/crops/${widget.cropId}/harvest'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );

      if (res.statusCode == 200) {
        await _fetchCropDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('অভিনন্দন! ফসল তোলা সম্পন্ন হয়েছে এবং খরচের মূল্যায়ন প্রস্তুত!'), backgroundColor: Color(0xFF2f8d5c)),
          );
          _navigateToExpenseDetails();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCrop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ফসল মুছুন', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('আপনি কি নিশ্চিত যে এই ফসলটি মুছে ফেলতে চান? এর সাথে যুক্ত সব টাস্ক এবং খরচের হিসাব চিরতরে মুছে যাবে।'),
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
        Uri.parse('http://localhost:5000/api/crops/${widget.cropId}'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ফসলটি মুছে ফেলা হয়েছে!'), backgroundColor: Colors.red));
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ডিলিট করতে সমস্যা হয়েছে! সার্ভার এরর।')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ইন্টারনেট বা কানেকশন সমস্যা!')));
      }
    }
  }

  void _showEditCropModal() {
    final typeController = TextEditingController(text: _cropData?['cropType'] ?? '');
    final varietyController = TextEditingController(text: _cropData?['variety'] ?? '');
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
                  const Text('ফসল সম্পাদনা করুন (Edit)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: typeController,
                    decoration: InputDecoration(labelText: 'ফসলের নাম', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: varietyController,
                    decoration: InputDecoration(labelText: 'জাত (Variety)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (typeController.text.trim().isEmpty) return;
                              setModalState(() => isSaving = true);
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);

                              try {
                                final res = await http.put(
                                  Uri.parse('http://localhost:5000/api/crops/${widget.cropId}'),
                                  headers: {
                                    'Content-Type': 'application/json',
                                    'Authorization': 'Bearer ${authProvider.token}',
                                  },
                                  body: jsonEncode({
                                    'cropType': typeController.text.trim(),
                                    'variety': varietyController.text.trim(),
                                  }),
                                );
                                if (res.statusCode == 200) {
                                  if (mounted) Navigator.pop(modalContext);
                                  _fetchCropDetails();
                                }
                              } catch (e) {
                                setModalState(() => isSaving = false);
                              }
                            },
                      child: isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('আপডেট করুন', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> _optimizeTasksWithAI() async {
    setState(() => _isOptimizing = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final res = await http.post(
        Uri.parse('http://localhost:5000/api/tasks/optimize-weather'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({'cropId': widget.cropId}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'কাজের তালিকা সমন্বয় করা হয়েছে!'), backgroundColor: const Color(0xFF2f8d5c)),
          );
          _fetchCropDetails();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('আজ কোনো পরিবর্তনের প্রয়োজন নেই।'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('সার্ভারে সংযোগ করা যায়নি।'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isOptimizing = false);
    }
  }

  Future<void> _toggleTaskStatus(String taskId, bool currentStatus) async {
    if (currentStatus) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final res = await http.put(
        Uri.parse('http://localhost:5000/api/tasks/$taskId/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (res.statusCode == 200) _fetchCropDetails();
    } catch (e) {}
  }

  void _showTaskDetailsModal(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final isUrgent = task['isUrgent'] == true;
        final cleanTitle = task['title'].toString().replaceAll('[AI Update]', '').trim();
        final description = (task['description'] != null && task['description'].toString().isNotEmpty)
            ? task['description']
            : 'এই কাজের জন্য কোনো বিস্তারিত নির্দেশনা নেই। সাধারণ নিয়মে কাজটি সম্পন্ন করুন।';

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(cleanTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d)))),
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade200)),
                      child: const Text('জরুরি', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text('কাজের ধরন: ${task['activityType'] ?? 'সাধারণ'}', style: const TextStyle(color: Color(0xFF2f8d5c), fontWeight: FontWeight.w600, fontSize: 13)),
              const Divider(height: 30, thickness: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('কীভাবে করবেন? (নির্দেশিকা):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Color(0xFF2f8d5c)),
                    tooltip: 'বাংলায় শুনুন',
                    onPressed: () => _speaker.speak('$cleanTitle। $description'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    _speaker.stop();
                    Navigator.pop(context);
                  },
                  child: const Text('বুঝেছি', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAskAIBottomSheet() {
    final issueController = TextEditingController();
    Uint8List? imageBytes;
    String? base64Image;
    bool isAILoading = false;
    String? aiResponse;
    String? issueId;
    bool isExpertRequested = false;
    String? selectedExpertName;
    final picker = ImagePicker();

    List<dynamic> availableExperts = [];
    bool isLoadingExperts = false;
    bool showExpertPicker = false;
    String? selectedExpertId;

    final stt.SpeechToText speech = stt.SpeechToText();
    bool isListening = false;
    bool isSpeaking = false;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String farmerDistrict = (authProvider.currentUser?.district ?? _cropData?['farmId']?['location'] ?? '').toString().trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void _listen() async {
              if (!isListening) {
                bool available = await speech.initialize(
                  onStatus: (val) {
                    if (val == 'done' || val == 'notListening') {
                      setModalState(() => isListening = false);
                    }
                  },
                  onError: (val) => setModalState(() => isListening = false),
                );
                if (available) {
                  setModalState(() => isListening = true);
                  speech.listen(
                    onResult: (val) => setModalState(() {
                      issueController.text = val.recognizedWords;
                    }),
                    localeId: 'bn_BD',
                  );
                }
              } else {
                setModalState(() => isListening = false);
                speech.stop();
              }
            }

            Future<void> _loadExpertsForSelection() async {
              setModalState(() {
                showExpertPicker = true;
                isLoadingExperts = true;
              });
              try {
                final res = await http.get(
                  Uri.parse('http://localhost:5000/api/experts'),
                  headers: {'Authorization': 'Bearer ${authProvider.token}'},
                );
                if (res.statusCode == 200) {
                  final list = jsonDecode(res.body) as List;
                  setModalState(() {
                    availableExperts = list;
                    if (list.isNotEmpty) {
                      selectedExpertId = list.first['_id'].toString();
                    }
                    isLoadingExperts = false;
                  });
                } else {
                  setModalState(() => isLoadingExperts = false);
                }
              } catch (e) {
                setModalState(() => isLoadingExperts = false);
              }
            }

            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
              decoration: const BoxDecoration(color: Color(0xFFF3faf4), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ফসলের ডাক্তার 🩺 (পরামর্শ কেন্দ্র)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            speech.stop();
                            _speaker.stop();
                            Navigator.pop(modalContext);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: issueController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'মুখে বলুন বা লিখুন: আপনার ফসলের কী সমস্যা দেখা যাচ্ছে?',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        suffixIcon: IconButton(
                          icon: Icon(isListening ? Icons.mic : Icons.mic_none, color: isListening ? Colors.red : const Color(0xFF2f8d5c), size: 26),
                          tooltip: 'মুখে বলুন',
                          onPressed: _listen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        InkWell(
                          onTap: () async {
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                            if (pickedFile != null) {
                              final bytes = await pickedFile.readAsBytes();
                              setModalState(() {
                                imageBytes = bytes;
                                base64Image = base64Encode(bytes);
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFedf9f1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.add_photo_alternate, color: Color(0xFF2f8d5c)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (imageBytes != null)
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(imageBytes!, width: 40, height: 40, fit: BoxFit.cover)),
                        const Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white),
                          onPressed: isAILoading
                              ? null
                              : () async {
                                  if (issueController.text.trim().isEmpty) return;
                                  setModalState(() => isAILoading = true);
                                  try {
                                    final res = await http.post(
                                      Uri.parse('http://localhost:5000/api/crops/${widget.cropId}/issues/ask-ai'),
                                      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'},
                                      body: jsonEncode({'issueText': issueController.text.trim(), 'imageBase64': base64Image}),
                                    );
                                    if (res.statusCode == 200) {
                                      final data = jsonDecode(res.body);
                                      final ans = (data['answer']?.toString() ?? '').replaceAll('**', '');
                                      setModalState(() {
                                        aiResponse = ans;
                                        issueId = data['issueId'];
                                        showExpertPicker = false;
                                        isExpertRequested = false;
                                      });
                                      _speaker.speak(
                                        ans,
                                        onStart: () => setModalState(() => isSpeaking = true),
                                        onComplete: () => setModalState(() => isSpeaking = false),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সার্ভারে সমস্যা হচ্ছে, আবার চেষ্টা করুন।')));
                                  } finally {
                                    setModalState(() => isAILoading = false);
                                  }
                                },
                          icon: isAILoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send, size: 16),
                          label: const Text('সমাধান দেখুন'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (aiResponse != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFFeef7f2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFcce8d9))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.medical_information, color: Color(0xFF2f8d5c), size: 18),
                                    SizedBox(width: 8),
                                    Text('প্রাথমিক কৃষি পরামর্শ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSpeaking ? Colors.redAccent : const Color(0xFF2f8d5c),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                  ),
                                  icon: Icon(isSpeaking ? Icons.stop : Icons.volume_up, size: 16),
                                  label: Text(isSpeaking ? 'থামুন' : 'বাংলায় শুনুন', style: const TextStyle(fontSize: 12)),
                                  onPressed: () => _speaker.speak(
                                    aiResponse!,
                                    onStart: () => setModalState(() => isSpeaking = true),
                                    onComplete: () => setModalState(() => isSpeaking = false),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(aiResponse!, style: const TextStyle(fontSize: 14, height: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (isExpertRequested)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFdcfce7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2f8d5c)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF15803d)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'আপনার সমস্যাটি "${selectedExpertName ?? 'কৃষি কর্মকর্তা'}"-এর কাছে সফলভাবে পাঠানো হয়েছে!',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14532d), fontSize: 13.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (!showExpertPicker)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF18392d),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: (isAILoading || issueId == null) ? null : _loadExpertsForSelection,
                            icon: const Icon(Icons.support_agent, size: 19),
                            label: const Text('এলাকা অনুযায়ী কৃষি বিশেষজ্ঞ বাছাই করে পাঠান', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2f8d5c), width: 1.5),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'কোন কৃষি কর্মকর্তার কাছে রিপোর্ট পাঠাতে চান বাছাই করুন:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF18392d)),
                                ),
                                const SizedBox(height: 10),
                                if (isLoadingExperts)
                                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Color(0xFF2f8d5c))))
                                else if (availableExperts.isEmpty)
                                  const Text('কোনো নিবন্ধিত বিশেষজ্ঞ পাওয়া যায়নি।', style: TextStyle(color: Colors.grey))
                                else ...[
                                  ...availableExperts.map((exp) {
                                    final expId = exp['_id'].toString();
                                    final expDist = (exp['district'] ?? 'সারাদেশ').toString();
                                    final bool isSameDistrict = farmerDistrict.isNotEmpty &&
                                        expDist.toLowerCase().contains(farmerDistrict.toLowerCase());
                                    final bool isOnline = exp['isAvailable'] != false;

                                    return RadioListTile<String>(
                                      value: expId,
                                      groupValue: selectedExpertId,
                                      activeColor: const Color(0xFF2f8d5c),
                                      contentPadding: EdgeInsets.zero,
                                      onChanged: (val) => setModalState(() => selectedExpertId = val),
                                      title: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              exp['name'] ?? 'কৃষি কর্মকর্তা',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF18392d)),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (isSameDistrict)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: const Color(0xFFdcfce7), borderRadius: BorderRadius.circular(6)),
                                              child: const Text('📍 আপনার এলাকার', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803d))),
                                            ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        '${exp['designation'] ?? 'কৃষি বিশেষজ্ঞ'} • 📍 $expDist • ${isOnline ? '🟢 অনলাইন' : '⚪ ব্যস্ত'}',
                                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2f8d5c),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: selectedExpertId == null
                                          ? null
                                          : () async {
                                              setModalState(() => isAILoading = true);
                                              try {
                                                final chosenExp = availableExperts.firstWhere(
                                                  (e) => e['_id'].toString() == selectedExpertId,
                                                  orElse: () => {},
                                                );
                                                final res = await http.put(
                                                  Uri.parse('http://localhost:5000/api/issues/$issueId/ask-expert'),
                                                  headers: {
                                                    'Content-Type': 'application/json',
                                                    'Authorization': 'Bearer ${authProvider.token}',
                                                  },
                                                  body: jsonEncode({'expertId': selectedExpertId}),
                                                );
                                                if (res.statusCode == 200) {
                                                  setModalState(() {
                                                    isExpertRequested = true;
                                                    selectedExpertName = chosenExp['name']?.toString();
                                                  });
                                                }
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('পাঠাতে সমস্যা হয়েছে।')));
                                              } finally {
                                                setModalState(() => isAILoading = false);
                                              }
                                            },
                                      icon: const Icon(Icons.send, size: 16),
                                      label: const Text('নির্বাচিত বিশেষজ্ঞের কাছে পাঠান', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _speaker.stop();
      _fetchCropIssues();
    });
  }

  void _showAllReportsModal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropReportsScreen(
          cropName: _displayItemName,
          cropIssues: _cropIssues,
          speaker: _speaker,
          onShare: (ctx, issueId, type) => _shareToCommunity(ctx, issueId, type),
          onAskNewAdvice: _showAskAIBottomSheet,
        ),
      ),
    );
    _speaker.stop();
    _fetchCropIssues();
  }

  void _showAddExpenseModal() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final customCategoryController = TextEditingController();
    String selectedCategory = 'Fertilizer';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bool isCustomCategory = selectedCategory == '__custom__';

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('নতুন খরচ যুক্ত করুন', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'খরচের খাত নির্বাচন করুন',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      items: [
                        ...kExpenseCategories.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Row(
                              children: [
                                Icon(entry.value['icon'] as IconData, color: entry.value['color'] as Color, size: 18),
                                const SizedBox(width: 10),
                                Text(entry.value['label'] as String, style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          );
                        }),
                        const DropdownMenuItem<String>(
                          value: '__custom__',
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline, color: Color(0xFF2f8d5c), size: 18),
                              SizedBox(width: 10),
                              Text('নতুন খাত লিখুন...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2f8d5c))),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (isCustomCategory) ...[
                      TextField(
                        controller: customCategoryController,
                        decoration: InputDecoration(
                          labelText: 'নতুন খাতের নাম লিখুন (যেমন: ট্রাক্টর ভাড়া / পরিবহন)',
                          prefixIcon: const Icon(Icons.edit_attributes, color: Color(0xFF2f8d5c)),
                          filled: true,
                          fillColor: const Color(0xFFedf9f1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'খরচের বিবরণ (যেমন: ইউরিয়া সার ২ বস্তা / ২ জন শ্রমিক)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'টাকার পরিমাণ (৳)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final amt = double.tryParse(amountController.text.trim());
                                if (amt == null || amt <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সঠিক টাকার পরিমাণ লিখুন।')));
                                  return;
                                }

                                final String finalCategory = isCustomCategory
                                    ? (customCategoryController.text.trim().isNotEmpty ? customCategoryController.text.trim() : 'অন্যান্য')
                                    : selectedCategory;

                                final String expTitle = titleController.text.trim().isNotEmpty
                                    ? titleController.text.trim()
                                    : (getCategoryMeta(finalCategory)['shortLabel'] as String);

                                setModalState(() => isSaving = true);
                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                try {
                                  final res = await http.post(
                                    Uri.parse('http://localhost:5000/api/crops/${widget.cropId}/expenses'),
                                    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'},
                                    body: jsonEncode({
                                      'title': expTitle,
                                      'category': finalCategory,
                                      'amount': amt,
                                    }),
                                  );
                                  if (res.statusCode == 200) {
                                    if (mounted) Navigator.pop(modalContext);
                                    _fetchCropDetails();
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                }
                              },
                        child: isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('খরচের হিসাব সেভ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddNoteModal() {
    final noteController = TextEditingController();
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
                  const Text('ডায়েরিতে নোট রাখুন', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'আপনার জমির পর্যবেক্ষণ এখানে লিখুন...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (noteController.text.isNotEmpty) {
                                setModalState(() => isSaving = true);
                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                try {
                                  final res = await http.post(
                                    Uri.parse('http://localhost:5000/api/crops/${widget.cropId}/notes'),
                                    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'},
                                    body: jsonEncode({'note': noteController.text}),
                                  );
                                  if (res.statusCode == 200) {
                                    if (mounted) Navigator.pop(modalContext);
                                    _fetchCropDetails();
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('নোট সেভ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> _navigateToExpenseDetails() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseDetailsScreen(
          cropId: widget.cropId,
          cropName: _displayItemName,
          totalExpense: _totalExpense,
          expenses: _expenses,
          initialAiAnalysis: _aiExpenseAnalysis,
          isHarvested: _currentStage.contains('Harvested') || _cropData?['status'] == 'Harvested',
        ),
      ),
    );
    _fetchCropDetails();
  }

  Future<void> _shareToCommunity(BuildContext context, String issueId, String solutionType) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF2f8d5c))),
    );

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/community/share-issue'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'},
        body: jsonEncode({
          'cropIssueId': issueId,
          'solutionType': solutionType,
        }),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('সফলভাবে কমিউনিটিতে শেয়ার করা হয়েছে!'), backgroundColor: Color(0xFF2f8d5c)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('শেয়ার করতে সমস্যা হয়েছে।'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ইন্টারনেট কানেকশন চেক করুন।'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3faf4),
        appBar: AppBar(backgroundColor: const Color(0xFF12362b), title: Text(_displayItemName, style: const TextStyle(color: Colors.white))),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF2f8d5c))),
      );
    }

    final bool isHarvested = _currentStage.contains('Harvested') || _cropData?['status'] == 'Harvested';

    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('$_displayItemName ড্যাশবোর্ড', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.white70), tooltip: 'Edit Crop', onPressed: _showEditCropModal),
          IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), tooltip: 'Delete Crop', onPressed: _deleteCrop),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ১. ফসলের ধাপ ও খরচের কার্ড
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ফসলের বর্তমান ধাপ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          _currentStage,
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: isHarvested ? Colors.orange.shade800 : const Color(0xFF18392d)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('বয়স: $_cropAgeDays দিন', style: const TextStyle(fontSize: 13, color: Color(0xFF2f8d5c), fontWeight: FontWeight.w600)),
                            if (!isHarvested)
                              InkWell(
                                onTap: _harvestCrop,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.shade400),
                                  ),
                                  child: const Text('🌾 ফসল তুলুন', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                                ),
                              )
                            else
                              const Text('✅ ঘরে তোলা হয়েছে', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('মোট উৎপাদন খরচ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('৳${_totalExpense.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(onTap: _showAddExpenseModal, child: const Text('+ খরচ যোগ', style: TextStyle(fontSize: 12, color: Color(0xFF2f8d5c), fontWeight: FontWeight.bold))),
                            InkWell(
                              onTap: _navigateToExpenseDetails,
                              child: const Row(
                                children: [
                                  Icon(Icons.pie_chart, size: 13, color: Color(0xFF2f8d5c)),
                                  SizedBox(width: 3),
                                  Text('খাতওয়ারী হিসাব >', style: TextStyle(fontSize: 11, color: Color(0xFF2f8d5c), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ২. আজকের কাজসমূহ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('আজকের কাজসমূহ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                _isOptimizing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2f8d5c)))
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF12362b),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _optimizeTasksWithAI,
                        icon: const Icon(Icons.wb_sunny_outlined, size: 15, color: Colors.amber),
                        label: const Text('আবহাওয়া অনুযায়ী সমন্বয়', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
            const SizedBox(height: 12),
            _todaysTasks.isEmpty
                ? const Padding(padding: EdgeInsets.all(8.0), child: Text('আজকের জন্য কোনো কাজ বাকি নেই!', style: TextStyle(color: Colors.grey)))
                : Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        children: _todaysTasks.map((task) {
                          final bool isTaskDone = task['status'] == 'Completed';
                          final bool isOverdue = task['isOverdue'] == true;
                          final String cleanTitle = task['title'].toString().replaceAll('[AI Update]', '').trim();
                          return CheckboxListTile(
                            activeColor: const Color(0xFF2f8d5c),
                            secondary: IconButton(
                              icon: const Icon(Icons.help_outline, color: Color(0xFF2f8d5c)),
                              onPressed: () => _showTaskDetailsModal(task),
                              tooltip: 'বিস্তারিত',
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    cleanTitle,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: isTaskDone ? TextDecoration.lineThrough : TextDecoration.none,
                                      color: isTaskDone ? Colors.grey : (isOverdue ? Colors.red : const Color(0xFF18392d)),
                                    ),
                                  ),
                                ),
                                if (isOverdue)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade200)),
                                    child: const Text('পিছিয়ে পড়া', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              task['isUrgent'] == true ? 'জরুরি কাজ' : 'নিয়মিত পরিচর্যা',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isTaskDone ? Colors.grey : (task['isUrgent'] == true ? Colors.red : Colors.orange)),
                            ),
                            value: isTaskDone,
                            onChanged: (bool? value) {
                              if (value == true) _toggleTaskStatus(task['_id'].toString(), isTaskDone);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
            const SizedBox(height: 24),

            // ৩. আগামী ২ দিনের কাজ
            const Text('আগামী ২ দিনের কাজ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
            const SizedBox(height: 12),
            _upcomingTasks.isEmpty
                ? const Padding(padding: EdgeInsets.all(8.0), child: Text('আগামী ৪৮ ঘণ্টায় কোনো নির্ধারিত কাজ নেই।', style: TextStyle(color: Colors.grey)))
                : Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        children: _upcomingTasks.map((task) {
                          final date = DateTime.parse(task['scheduledDate'].toString());
                          final String cleanTitle = task['title'].toString().replaceAll('[AI Update]', '').trim();
                          return ListTile(
                            onTap: () => _showTaskDetailsModal(task),
                            leading: const CircleAvatar(backgroundColor: Color(0xFFedf9f1), child: Icon(Icons.calendar_month, color: Color(0xFF2f8d5c), size: 18)),
                            title: Text(cleanTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                            subtitle: Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
            const SizedBox(height: 24),

            // ৪. পরবর্তী ধাপের কাজসমূহ
            if (_laterTasks.isNotEmpty) ...[
              const Text('পরবর্তী ধাপের কাজসমূহ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: _laterTasks.map((task) {
                      final date = DateTime.parse(task['scheduledDate'].toString());
                      final String cleanTitle = task['title'].toString().replaceAll('[AI Update]', '').trim();
                      return ListTile(
                        onTap: () => _showTaskDetailsModal(task),
                        leading: const CircleAvatar(backgroundColor: Color(0xFFf5f5f5), child: Icon(Icons.schedule, color: Colors.grey, size: 18)),
                        title: Text(cleanTitle, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                        subtitle: Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ৫. খামার ডায়েরি
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('খামার ডায়েরি', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                TextButton(onPressed: _showAddNoteModal, child: const Text('+ নোট লিখুন', style: TextStyle(color: Color(0xFF2f8d5c), fontWeight: FontWeight.bold))),
              ],
            ),
            _notes.isEmpty
                ? const Text('এখনো কোনো ডায়েরি নোট যুক্ত করা হয়নি।', style: TextStyle(color: Colors.grey))
                : Column(
                    children: _notes
                        .map(
                          (note) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFe6f4ea)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.edit_note, color: Colors.grey, size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text(note['note']?.toString() ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF4d6e60), height: 1.4))),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
            const SizedBox(height: 20),

            // ৬. রোগবালাই ও সমাধানের রিপোর্ট অপশন
            InkWell(
              onTap: _showAllReportsModal,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFcce8d9)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFedf9f1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.assignment_outlined, color: Color(0xFF2f8d5c), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'রোগবালাই ও সমাধানের রিপোর্ট',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _cropIssues.isEmpty
                                ? 'এখনো কোনো রিপোর্ট নেই • দেখতে ক্লিক করুন'
                                : 'মোট ${_cropIssues.length}টি রিপোর্ট সংরক্ষিত আছে • দেখতে ক্লিক করুন',
                            style: const TextStyle(fontSize: 12.5, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2f8d5c),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_cropIssues.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ৭. ফসলের ডাক্তার বক্স (পেজের একদম শেষে স্থায়ীভাবে বসানো)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18392d),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF2f8d5c),
                    child: Icon(Icons.medical_services, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ফসলের ডাক্তার', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5)),
                        SizedBox(height: 3),
                        Text('ফসলের রোগবালাই হলে ছবি বা ভয়েস পাঠান', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF18392d),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showAskAIBottomSheet,
                    child: const Text('পরামর্শ নিন', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 📊 কৃষক-বান্ধব খরচের খাতওয়ারী হিসাব ও সাশ্রয়ী পরামর্শ স্ক্রিন
// =========================================================================
class ExpenseDetailsScreen extends StatefulWidget {
  final String cropId;
  final String cropName;
  final double totalExpense;
  final List<dynamic> expenses;
  final String initialAiAnalysis;
  final bool isHarvested;

  const ExpenseDetailsScreen({
    super.key,
    required this.cropId,
    required this.cropName,
    required this.totalExpense,
    required this.expenses,
    required this.initialAiAnalysis,
    required this.isHarvested,
  });

  @override
  State<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends State<ExpenseDetailsScreen> {
  late String _savingAdvice;
  bool _isEvaluating = false;
  bool _isSpeaking = false;
  final SmartBengaliSpeaker _speaker = SmartBengaliSpeaker();

  @override
  void initState() {
    super.initState();
    _savingAdvice = widget.initialAiAnalysis;
    if (_savingAdvice.isEmpty && widget.expenses.isNotEmpty && widget.totalExpense > 0) {
      _evaluateCostSavings(autoTrigger: true);
    }
  }

  @override
  void dispose() {
    _speaker.stop();
    super.dispose();
  }

  String _resolveCategory(Map<String, dynamic> exp) {
    final cat = exp['category']?.toString().trim();
    if (cat != null && cat.isNotEmpty && cat != 'Other') {
      return cat;
    }
    final title = (exp['title']?.toString() ?? '').toLowerCase();
    if (title.contains('সার') || title.contains('fertilizer') || title.contains('ইউরিয়া') || title.contains('টিএসপি') || title.contains('পটাশ')) {
      return 'Fertilizer';
    }
    if (title.contains('লেবার') || title.contains('labor') || title.contains('শ্রমিক') || title.contains('মজুরি')) {
      return 'Labor';
    }
    if (title.contains('ওষুধ') || title.contains('কীটনাশক') || title.contains('pesticide') || title.contains('medicine') || title.contains('স্প্রে')) {
      return 'Pesticide';
    }
    if (title.contains('বীজ') || title.contains('চারা') || title.contains('seed')) {
      return 'Seeds';
    }
    if (title.contains('সেচ') || title.contains('পানি') || title.contains('water') || title.contains('irrigation')) {
      return 'Irrigation';
    }
    return (cat != null && cat.isNotEmpty) ? cat : 'Other';
  }

  Map<String, double> _getCategoryTotals() {
    final Map<String, double> totals = {};
    for (var raw in widget.expenses) {
      final exp = Map<String, dynamic>.from(raw as Map);
      final cat = _resolveCategory(exp);
      final amt = (exp['amount'] ?? 0).toDouble();
      if (amt > 0) {
        totals[cat] = (totals[cat] ?? 0.0) + amt;
      }
    }
    return totals;
  }

  MapEntry<String, double>? _getHighestCategory(Map<String, double> totals) {
    if (totals.isEmpty) return null;
    var entries = totals.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.first;
  }

  Future<void> _evaluateCostSavings({bool autoTrigger = false}) async {
    if (widget.expenses.isEmpty || widget.totalExpense <= 0) return;
    if (mounted) setState(() => _isEvaluating = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.post(
        Uri.parse('http://localhost:5000/api/crops/${widget.cropId}/analyze-expenses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _savingAdvice = data['aiExpenseAnalysis']?.toString() ?? '';
          });
        }
      }
    } catch (e) {
      if (!autoTrigger && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('হিসাব মূল্যায়ন করতে সমস্যা হয়েছে।')),
        );
      }
    } finally {
      if (mounted) setState(() => _isEvaluating = false);
    }
  }

  String _buildFullBengaliAudioScript(MapEntry<String, double>? highestEntry) {
    String intro = '${widget.cropName} চাষে আপনার মোট খরচ হয়েছে ${widget.totalExpense.toStringAsFixed(0)} টাকা। ';
    if (highestEntry != null) {
      final catName = getCategoryMeta(highestEntry.key)['shortLabel'];
      final pct = ((highestEntry.value / widget.totalExpense) * 100).toStringAsFixed(0);
      intro += 'সবচেয়ে বেশি খরচ হয়েছে $catName খাতে, যা মোট খরচের $pct শতাংশ। ';
    }
    if (_savingAdvice.isNotEmpty) {
      intro += 'খরচ কমানোর পরামর্শ: $_savingAdvice';
    } else {
      intro += 'সুষম জৈব ও কম্পোস্ট সার ব্যবহার করলে আগামী মৌসুমে খরচ পনেরো থেকে বিশ শতাংশ কমানো সম্ভব।';
    }
    return intro;
  }

  @override
  Widget build(BuildContext context) {
    final categoryTotals = _getCategoryTotals();
    final highestCategory = _getHighestCategory(categoryTotals);

    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('খরচের খাতওয়ারী হিসাব ও পরামর্শ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2f8d5c), Color(0xFF64b87a)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('${widget.cropName} চাষের হিসাব', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('সর্বমোট খরচ', style: TextStyle(color: Colors.white, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('৳${widget.totalExpense.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (categoryTotals.isNotEmpty && widget.totalExpense > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('কোন খাতে কত খরচ হয়েছে?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: CustomPaint(
                            painter: _ExpensePieChartPainter(
                              categoryTotals: categoryTotals,
                              total: widget.totalExpense,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('মোট খাত', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text('${categoryTotals.length}টি', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: categoryTotals.entries.map((entry) {
                              final catInfo = getCategoryMeta(entry.key);
                              final pct = (entry.value / widget.totalExpense) * 100;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: catInfo['color'] as Color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        catInfo['shortLabel'] as String,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF18392d)),
                                      ),
                                    ),
                                    Text(
                                      '${pct.toStringAsFixed(0)}% (৳${entry.value.toStringAsFixed(0)})',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFeef7f2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFbce3c8), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.tips_and_updates, color: Color(0xFF2f8d5c), size: 22),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'খরচ কমানোর ও সাশ্রয়ী চাষাবাদ পরামর্শ',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSpeaking ? Colors.redAccent : const Color(0xFF2f8d5c),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final script = _buildFullBengaliAudioScript(highestCategory);
                            _speaker.speak(
                              script,
                              onStart: () => setState(() => _isSpeaking = true),
                              onComplete: () => setState(() => _isSpeaking = false),
                            );
                          },
                          icon: Icon(_isSpeaking ? Icons.stop_circle : Icons.volume_up, size: 17),
                          label: Text(
                            _isSpeaking ? 'থামুন' : 'বাংলায় শুনুন',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (highestCategory != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'আপনার সবচেয়ে বেশি খরচ হয়েছে "${getCategoryMeta(highestCategory.key)['shortLabel']}" খাতে (${((highestCategory.value / widget.totalExpense) * 100).toStringAsFixed(0)}%)।',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_isEvaluating)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2f8d5c))),
                            SizedBox(width: 10),
                            Text('আপনার খরচের খাতগুলো মূল্যায়ন করা হচ্ছে...', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                          ],
                        ),
                      )
                    else
                      Text(
                        _savingAdvice.isNotEmpty
                            ? _savingAdvice
                            : 'আপনার খরচের হিসাব অনুযায়ী সুষম জৈব ও কম্পোস্ট সার ব্যবহার এবং সমন্বিত বালাই ব্যবস্থাপনা অনুসরণ করলে আগামী মৌসুমে উৎপাদন খরচ ১৫% থেকে ২০% পর্যন্ত কমিয়ে আনা সম্ভব।',
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF18392d),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isEvaluating ? null : () => _evaluateCostSavings(autoTrigger: false),
                        icon: const Icon(Icons.refresh, size: 15, color: Color(0xFF2f8d5c)),
                        label: const Text(
                          'পরামর্শ হালনাগাদ করুন',
                          style: TextStyle(fontSize: 12, color: Color(0xFF2f8d5c), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Text('সকল খরচের বিবরণ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
            const SizedBox(height: 12),
            widget.expenses.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: Text('এখনো কোনো খরচের হিসাব যোগ করা হয়নি।', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.expenses.length,
                    itemBuilder: (context, index) {
                      final exp = Map<String, dynamic>.from(widget.expenses[index] as Map);
                      final catKey = _resolveCategory(exp);
                      final catInfo = getCategoryMeta(catKey);
                      final Color catColor = catInfo['color'] as Color;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: catColor.withValues(alpha: 0.12),
                              child: Icon(catInfo['icon'] as IconData, color: catColor, size: 20),
                            ),
                            title: Text(exp['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            subtitle: Text(catInfo['shortLabel'] as String, style: TextStyle(fontSize: 12, color: catColor, fontWeight: FontWeight.w600)),
                            trailing: Text('৳${exp['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF18392d))),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

class _ExpensePieChartPainter extends CustomPainter {
  final Map<String, double> categoryTotals;
  final double total;

  _ExpensePieChartPainter({required this.categoryTotals, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || categoryTotals.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;

    categoryTotals.forEach((catKey, amount) {
      final sweepAngle = (amount / total) * 2 * math.pi;
      final catInfo = getCategoryMeta(catKey);
      final paint = Paint()
        ..color = catInfo['color'] as Color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle - 0.03, false, paint);
      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =========================================================================
// 📋 রোগবালাই ও সমাধানের রিপোর্ট ফুল-স্ক্রিন পেজ
// =========================================================================
class CropReportsScreen extends StatelessWidget {
  final String cropName;
  final List<dynamic> cropIssues;
  final SmartBengaliSpeaker speaker;
  final Function(BuildContext, String, String) onShare;
  final VoidCallback onAskNewAdvice;

  const CropReportsScreen({
    super.key,
    required this.cropName,
    required this.cropIssues,
    required this.speaker,
    required this.onShare,
    required this.onAskNewAdvice,
  });

  String _cleanAdviceText(String raw) {
    return raw.replaceAll('**', '').replaceAll('##', '').trim();
  }

  String _formatReportDate(dynamic dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr.toString());
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showFullImageDialog(BuildContext context, Uint8List imageBytes, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.memory(imageBytes, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '$cropName - সকল রিপোর্ট (${cropIssues.length})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: cropIssues.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.medical_information_outlined, size: 54, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'এখনো কোনো সমস্যার রিপোর্ট করা হয়নি।',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2f8d5c),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onAskNewAdvice();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('নতুন পরামর্শ নিন', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cropIssues.length,
              itemBuilder: (context, index) {
                final issue = cropIssues[index];
                final String issueTitle = issue['issueText']?.toString() ?? '';
                final String reportDate = _formatReportDate(issue['createdAt']);
                final String rawAiAdvice = issue['aiAdvice']?.toString() ?? '';
                final String cleanAiAdvice = _cleanAdviceText(rawAiAdvice);

                Uint8List? issueImageBytes;
                final String? base64Str = issue['imageBase64']?.toString();
                if (base64Str != null && base64Str.trim().isNotEmpty) {
                  try {
                    final cleanBase64 = base64Str.contains(',')
                        ? base64Str.split(',').last.trim()
                        : base64Str.trim();
                    issueImageBytes = base64Decode(cleanBase64);
                  } catch (e) {
                    debugPrint('Image decode error: $e');
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFcce8d9)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2.0),
                            child: Icon(Icons.help_outline, color: Colors.orange, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              issueTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Color(0xFF18392d)),
                            ),
                          ),
                          if (reportDate.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFedf9f1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today, size: 11, color: Color(0xFF2f8d5c)),
                                  const SizedBox(width: 4),
                                  Text(
                                    reportDate,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF2f8d5c), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      if (issueImageBytes != null) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _showFullImageDialog(context, issueImageBytes!, issueTitle),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFcce8d9)),
                            ),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.memory(
                                    issueImageBytes,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_in, color: Colors.white, size: 15),
                                      SizedBox(width: 4),
                                      Text(
                                        'আপনার পাঠানো ছবি (বড় করে দেখুন)',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFf4f6f8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '📋 কৃষি পরামর্শ:',
                                  style: TextStyle(fontSize: 13.5, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                                ),
                                if (cleanAiAdvice.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.volume_up, size: 20, color: Color(0xFF2f8d5c)),
                                    tooltip: 'বাংলায় শুনুন',
                                    onPressed: () => speaker.speak(cleanAiAdvice),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cleanAiAdvice.isNotEmpty ? cleanAiAdvice : 'অপেক্ষমান...',
                              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                            ),
                            if (cleanAiAdvice.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFedf9f1),
                                    foregroundColor: const Color(0xFF2f8d5c),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => onShare(context, issue['_id'].toString(), 'AI'),
                                  icon: const Icon(Icons.share, size: 15),
                                  label: const Text('কমিউনিটিতে শেয়ার করুন', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                      ),

                      if (issue['expertReply'] != null && issue['expertReply'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFedf9f1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFcce8d9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.verified, color: Color(0xFF2f8d5c), size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        '👨‍🌾 কৃষি কর্মকর্তার প্রেসক্রিপশন:',
                                        style: TextStyle(fontSize: 13.5, color: Color(0xFF12362b), fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.volume_up, size: 20, color: Color(0xFF2f8d5c)),
                                    onPressed: () => speaker.speak(issue['expertReply'].toString()),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _cleanAdviceText(issue['expertReply'].toString()),
                                style: const TextStyle(fontSize: 14, color: Color(0xFF18392d), fontWeight: FontWeight.w600, height: 1.5),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF2f8d5c),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => onShare(context, issue['_id'].toString(), 'Expert'),
                                  icon: const Icon(Icons.share, size: 15),
                                  label: const Text('কমিউনিটিতে শেয়ার করুন', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (issue['status'] == 'Pending_Expert') ...[
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Icon(Icons.pending_actions, color: Colors.orange, size: 15),
                            SizedBox(width: 6),
                            Text(
                              'কৃষি কর্মকর্তার উত্তরের অপেক্ষায়...',
                              style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}