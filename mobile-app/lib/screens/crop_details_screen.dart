import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

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
  String _currentStage = 'Germination';
  String _displayItemName = '';

  List<dynamic> _todaysTasks = [];
  List<dynamic> _upcomingTasks = [];
  List<dynamic> _laterTasks = []; // 🚀 দূরের কাজের জন্য
  List<dynamic> _expenses = [];
  List<dynamic> _notes = [];
  List<dynamic> _cropIssues = []; 

  @override
  void initState() {
    super.initState();
    _displayItemName = widget.itemName;
    _fetchCropDetails();
    _fetchCropIssues(); 
  }

  Future<void> _fetchCropDetails() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/crops/${widget.cropId}/details'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final crop = data['crop'];
        List<dynamic> tasks = data['tasks'] as List;

        final sowingDate = DateTime.parse(crop['sowingDate'].toString());
        final now = DateTime.now();
        final age = now.difference(sowingDate).inDays;

        // 🚀 তারিখ অনুযায়ী টাস্কগুলোকে আগে সাজিয়ে (Sort) নেওয়া হলো
        tasks.sort((a, b) {
          final dateA = DateTime.parse(a['scheduledDate'].toString());
          final dateB = DateTime.parse(b['scheduledDate'].toString());
          return dateA.compareTo(dateB);
        });

        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final dayAfterTomorrow = today.add(const Duration(days: 2));

        List<dynamic> todayTasksList = [];
        List<dynamic> upcomingTasksList = [];
        List<dynamic> laterTasksList = [];

        // 🚀 সুপার স্মার্ট টাস্ক ফিল্টারিং লজিক (Today, Upcoming: Tomorrow+DayAfter, Later)
        for (var task in tasks) {
          final taskDateTime = DateTime.parse(task['scheduledDate'].toString());
          final taskDate = DateTime(taskDateTime.year, taskDateTime.month, taskDateTime.day);
          final isCompleted = task['status'] == 'Completed';

          if (taskDate.isBefore(today)) {
            // অতীতের অসমাপ্ত কাজ Today-তে Overdue হিসেবে দেখাবে
            if (!isCompleted) {
              task['isOverdue'] = true;
              todayTasksList.add(task);
            }
          } else if (taskDate.isAtSameMomentAs(today)) {
            // আজকের কাজ
            todayTasksList.add(task);
          } else if (taskDate.isAtSameMomentAs(tomorrow) || taskDate.isAtSameMomentAs(dayAfterTomorrow)) {
            // শুধুমাত্র আগামীকাল এবং পরশুর কাজ
            upcomingTasksList.add(task);
          } else if (taskDate.isAfter(dayAfterTomorrow)) {
            // পরশুর পরের সব কাজ
            laterTasksList.add(task);
          }
        }

        // 🚀 Upcoming লিস্টে সর্বোচ্চ ৪-৫টি কাজ রাখা এবং বাকিগুলো Later-এ পাঠিয়ে দেওয়া
        if (upcomingTasksList.length > 5) {
          laterTasksList.insertAll(0, upcomingTasksList.sublist(5));
          upcomingTasksList = upcomingTasksList.sublist(0, 5);
        }

        if (mounted) {
          setState(() {
            _cropData = crop;
            _displayItemName = crop['cropType'] ?? widget.itemName; 
            _totalExpense = (crop['totalExpense'] ?? 0).toDouble();
            _expenses = crop['expenses'] ?? [];
            _notes = crop['diaryNotes'] ?? [];
            _cropAgeDays = age >= 0 ? age : 0;
            _currentStage = crop['currentStage'] ?? 'Germination';
            
            _todaysTasks = todayTasksList;
            _upcomingTasks = upcomingTasksList;
            _laterTasks = laterTasksList;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
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
                    decoration: InputDecoration(labelText: 'Crop Type (e.g. Potato)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: varietyController,
                    decoration: InputDecoration(labelText: 'Variety (e.g. Diamond)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: isSaving ? null : () async {
                        if (typeController.text.trim().isEmpty) return;
                        setModalState(() => isSaving = true);
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);

                        try {
                          final res = await http.put(
                            Uri.parse('http://localhost:5000/api/crops/${widget.cropId}'),
                            headers: {
                              'Content-Type': 'application/json',
                              'Authorization': 'Bearer ${authProvider.token}'
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
                      child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Update Crop', style: TextStyle(fontWeight: FontWeight.bold)),
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
            SnackBar(content: Text(data['message'] ?? 'Tasks Optimized!'), backgroundColor: const Color(0xFF2f8d5c)),
          );
          _fetchCropDetails();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No tasks needed optimization today.'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to AI server.'), backgroundColor: Colors.red),
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
        final description = (task['description'] != null && task['description'].toString().isNotEmpty) ? task['description'] : 'এই কাজের জন্য এআই এর কোনো বিস্তারিত গাইডেন্স নেই। সাধারণ নিয়মে কাজটি সম্পন্ন করুন।';

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(task['title'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d)))),
                  if (isUrgent) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade200)), child: const Text('URGENT', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 6),
              Text('Activity Type: ${task['activityType'] ?? 'Other'}', style: const TextStyle(color: Color(0xFF2f8d5c), fontWeight: FontWeight.w600, fontSize: 13)),
              const Divider(height: 30, thickness: 1),
              const Text('কীভাবে করবেন? (Step-by-step Guide):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 12),
              Text(description, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)),
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () => Navigator.pop(context), child: const Text('Got it!', style: TextStyle(fontWeight: FontWeight.bold)))),
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
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                        const Text('Crop Doctor 🩺', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(modalContext)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: issueController, maxLines: 3, decoration: InputDecoration(hintText: 'আপনার ফসলের কী সমস্যা হচ্ছে? (যেমন: পাতায় হলুদ দাগ, পোকা...)', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        InkWell(
                          onTap: () async {
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                            if (pickedFile != null) {
                              final bytes = await pickedFile.readAsBytes();
                              setModalState(() { imageBytes = bytes; base64Image = base64Encode(bytes); });
                            }
                          },
                          child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFedf9f1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_photo_alternate, color: Color(0xFF2f8d5c))),
                        ),
                        const SizedBox(width: 10),
                        if (imageBytes != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(imageBytes!, width: 40, height: 40, fit: BoxFit.cover)),
                        const Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white),
                          onPressed: isAILoading ? null : () async {
                            if (issueController.text.trim().isEmpty) return;
                            setModalState(() => isAILoading = true);
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            try {
                              final res = await http.post(Uri.parse('http://localhost:5000/api/crops/${widget.cropId}/issues/ask-ai'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'}, body: jsonEncode({'issueText': issueController.text.trim(), 'imageBase64': base64Image}));
                              if (res.statusCode == 200) {
                                final data = jsonDecode(res.body);
                                setModalState(() { aiResponse = data['answer']; issueId = data['issueId']; });
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI Error! সার্ভারে সমস্যা হচ্ছে।')));
                            } finally { setModalState(() => isAILoading = false); }
                          },
                          icon: isAILoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, size: 16),
                          label: const Text('পরামর্শ নিন'),
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
                            const Row(children: [Icon(Icons.smart_toy, color: Color(0xFF2f8d5c), size: 18), SizedBox(width: 8), Text('কৃষি বিশেষজ্ঞের (AI) পরামর্শ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF18392d)))]),
                            const SizedBox(height: 8),
                            Text(aiResponse!, style: const TextStyle(fontSize: 14, height: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: isExpertRequested ? Colors.grey.shade300 : const Color(0xFF18392d), foregroundColor: isExpertRequested ? Colors.grey : Colors.white),
                          onPressed: (isAILoading || isExpertRequested || issueId == null) ? null : () async {
                            setModalState(() => isAILoading = true);
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            try {
                              final res = await http.put(Uri.parse('http://localhost:5000/api/issues/$issueId/ask-expert'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'});
                              if (res.statusCode == 200) {
                                setModalState(() => isExpertRequested = true);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('আপনার সমস্যাটি বিশেষজ্ঞের কাছে পাঠানো হয়েছে।'), backgroundColor: Color(0xFF2f8d5c)));
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error escalating to expert.')));
                            } finally { setModalState(() => isAILoading = false); }
                          },
                          icon: const Icon(Icons.support_agent, size: 18),
                          label: Text(isExpertRequested ? 'বিশেষজ্ঞের কাছে পাঠানো হয়েছে' : 'আসল বিশেষজ্ঞের সহায়তা নিন'),
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
    ).whenComplete(() { _fetchCropIssues(); });
  }

  void _showAddExpenseModal() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
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
                  const Text('Add New Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                  const SizedBox(height: 16),
                  TextField(controller: titleController, decoration: InputDecoration(labelText: 'Expense Purpose (e.g. Fertilizer)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 12),
                  TextField(controller: amountController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Amount (Tk)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: isSaving ? null : () async {
                        if (titleController.text.isNotEmpty && amountController.text.isNotEmpty) {
                          setModalState(() => isSaving = true);
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          try {
                            final res = await http.post(Uri.parse('http://localhost:5000/api/crops/${widget.cropId}/expenses'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'}, body: jsonEncode({'title': titleController.text, 'amount': amountController.text}));
                            if (res.statusCode == 200) { if (mounted) Navigator.pop(modalContext); _fetchCropDetails(); }
                          } catch (e) { setModalState(() => isSaving = false); }
                        }
                      },
                      child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Expense', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  const Text('Add Farm Diary Note', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                  const SizedBox(height: 16),
                  TextField(controller: noteController, maxLines: 3, decoration: InputDecoration(hintText: 'Write your observation here...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: isSaving ? null : () async {
                        if (noteController.text.isNotEmpty) {
                          setModalState(() => isSaving = true);
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          try {
                            final res = await http.post(Uri.parse('http://localhost:5000/api/crops/${widget.cropId}/notes'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'}, body: jsonEncode({'note': noteController.text}));
                            if (res.statusCode == 200) { if (mounted) Navigator.pop(modalContext); _fetchCropDetails(); }
                          } catch (e) { setModalState(() => isSaving = false); }
                        }
                      },
                      child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Note', style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _navigateToExpenseDetails() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseDetailsScreen(cropName: _displayItemName, totalExpense: _totalExpense, expenses: _expenses)));
  }

  // কমিউনিটিতে শেয়ার করার ফাংশন
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}'
        },
        body: jsonEncode({
          'cropIssueId': issueId,
          'solutionType': solutionType,
        }),
      );

      Navigator.pop(context); // লোডিং বন্ধ

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ সফলভাবে কমিউনিটিতে শেয়ার করা হয়েছে!'), backgroundColor: Color(0xFF2f8d5c)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('শেয়ার করতে সমস্যা হয়েছে।'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ইন্টারনেট কানেকশন চেক করুন।'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: const Color(0xFFF3faf4), appBar: AppBar(backgroundColor: const Color(0xFF12362b), title: Text(_displayItemName, style: const TextStyle(color: Colors.white))), body: const Center(child: CircularProgressIndicator(color: Color(0xFF2f8d5c))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('$_displayItemName Dashboard', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.white70), tooltip: 'Edit Crop', onPressed: _showEditCropModal),
          IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), tooltip: 'Delete Crop', onPressed: _deleteCrop),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CURRENT STAGE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_currentStage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                        Text('Day $_cropAgeDays', style: const TextStyle(fontSize: 14, color: Color(0xFF2f8d5c), fontWeight: FontWeight.w600)),
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
                        const Text('TOTAL EXPENSE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('৳$_totalExpense', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(onTap: _showAddExpenseModal, child: const Text('+ Add', style: TextStyle(fontSize: 12, color: Color(0xFF2f8d5c), fontWeight: FontWeight.bold))),
                            InkWell(onTap: _navigateToExpenseDetails, child: const Text('Details >', style: TextStyle(fontSize: 12, color: Color(0xFF2f8d5c), fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 🚀 1. TODAY'S ACTIVITIES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Today\'s Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                _isOptimizing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2f8d5c))) : ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF12362b), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _optimizeTasksWithAI, icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.amber), label: const Text('AI Optimize', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 12),
            _todaysTasks.isEmpty
                ? const Padding(padding: EdgeInsets.all(8.0), child: Text('No pending tasks for today!', style: TextStyle(color: Colors.grey)))
                : Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]), child: Column(children: _todaysTasks.map((task) { final bool isTaskDone = task['status'] == 'Completed'; final bool isOverdue = task['isOverdue'] == true; return CheckboxListTile(activeColor: const Color(0xFF2f8d5c), secondary: IconButton(icon: const Icon(Icons.help_outline, color: Color(0xFF2f8d5c)), onPressed: () => _showTaskDetailsModal(task), tooltip: 'View Details'), title: Row(children: [Expanded(child: Text(task['title'].toString(), style: TextStyle(fontWeight: FontWeight.bold, decoration: isTaskDone ? TextDecoration.lineThrough : TextDecoration.none, color: isTaskDone ? Colors.grey : (isOverdue ? Colors.red : const Color(0xFF18392d))))), if (isOverdue) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade200)), child: const Text('Missed', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)))]), subtitle: Text(task['isUrgent'] == true ? 'High Priority' : 'Routine', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isTaskDone ? Colors.grey : (task['isUrgent'] == true ? Colors.red : Colors.orange))), value: isTaskDone, onChanged: (bool? value) { if (value == true) _toggleTaskStatus(task['_id'].toString(), isTaskDone); }); }).toList())),
            const SizedBox(height: 24),

            // 🚀 2. UPCOMING ACTIVITIES (Tomorrow & Day After)
            const Text('Upcoming (Tomorrow & Next Day)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
            const SizedBox(height: 12),
            _upcomingTasks.isEmpty
                ? const Padding(padding: EdgeInsets.all(8.0), child: Text('No upcoming tasks for next 48 hours.', style: TextStyle(color: Colors.grey)))
                : Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]), child: Column(children: _upcomingTasks.map((task) { final date = DateTime.parse(task['scheduledDate'].toString()); return ListTile(onTap: () => _showTaskDetailsModal(task), leading: const CircleAvatar(backgroundColor: Color(0xFFedf9f1), child: Icon(Icons.calendar_month, color: Color(0xFF2f8d5c), size: 18)), title: Text(task['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF18392d))), subtitle: Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)), trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)); }).toList())),
            const SizedBox(height: 24),

            // 🚀 3. LATER ACTIVITIES
            if (_laterTasks.isNotEmpty) ...[
              const Text('Later Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
              const SizedBox(height: 12),
              Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]), child: Column(children: _laterTasks.map((task) { final date = DateTime.parse(task['scheduledDate'].toString()); return ListTile(onTap: () => _showTaskDetailsModal(task), leading: const CircleAvatar(backgroundColor: Color(0xFFf5f5f5), child: Icon(Icons.schedule, color: Colors.grey, size: 18)), title: Text(task['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)), subtitle: Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(fontSize: 12, color: Colors.grey)), trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)); }).toList())),
              const SizedBox(height: 24),
            ],

            // 4. FARM DIARY
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Farm Diary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))), TextButton(onPressed: _showAddNoteModal, child: const Text('Add Note', style: TextStyle(color: Color(0xFF2f8d5c), fontWeight: FontWeight.bold)))]),
            _notes.isEmpty
                ? const Text('No diary notes added yet.', style: TextStyle(color: Colors.grey))
                : Column(children: _notes.map((note) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFe6f4ea)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)]), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.edit_note, color: Colors.grey, size: 20), const SizedBox(width: 12), Expanded(child: Text(note['note']?.toString() ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF4d6e60), height: 1.4)))]) )).toList()),
            const SizedBox(height: 24),
            
            // 5. DOCTOR REPORTS
            const Text('Doctor Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
            const SizedBox(height: 12),
            _cropIssues.isEmpty
                ? const Text('কোনো সমস্যা রিপোর্ট করা হয়নি।', style: TextStyle(color: Colors.grey))
                : Column(children: _cropIssues.map((issue) => Container(
                  margin: const EdgeInsets.only(bottom: 12), 
                  padding: const EdgeInsets.all(16), 
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFe6f4ea))), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline, color: Colors.orange, size: 18), 
                          const SizedBox(width: 8), 
                          Expanded(child: Text(issue['issueText']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))
                        ]
                      ), 
                      const SizedBox(height: 12), 
                      
                      // AI Suggestion Box
                      Container(
                        width: double.infinity, 
                        padding: const EdgeInsets.all(10), 
                        decoration: BoxDecoration(color: const Color(0xFFf4f6f8), borderRadius: BorderRadius.circular(8)), 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            const Text('🤖 AI Suggestion:', style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)), 
                            const SizedBox(height: 4), 
                            Text(issue['aiAdvice']?.toString() ?? 'অপেক্ষমান...', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            
                            // Share Button for AI Suggestion
                            if (issue['aiAdvice'] != null && issue['aiAdvice'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFedf9f1),
                                    foregroundColor: const Color(0xFF2f8d5c),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    _shareToCommunity(context, issue['_id'].toString(), 'AI');
                                  },
                                  icon: const Icon(Icons.share, size: 16),
                                  label: const Text('এই সমাধানটি কমিউনিটিতে শেয়ার করুন', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                          ]
                        )
                      ), 
                      
                      // Expert Reply Box
                      if (issue['expertReply'] != null && issue['expertReply'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12), 
                        Container(
                          width: double.infinity, 
                          padding: const EdgeInsets.all(10), 
                          decoration: BoxDecoration(color: const Color(0xFFedf9f1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFcce8d9))), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              const Row(children: [Icon(Icons.verified, color: Color(0xFF2f8d5c), size: 14), SizedBox(width: 6), Text('👨‍🌾 Expert Reply:', style: TextStyle(fontSize: 12, color: Color(0xFF12362b), fontWeight: FontWeight.bold))]), 
                              const SizedBox(height: 4), 
                              Text(issue['expertReply'].toString(), style: const TextStyle(fontSize: 14, color: Color(0xFF18392d), fontWeight: FontWeight.w600)),

                              // Share Button for Expert Reply
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFedf9f1),
                                    foregroundColor: const Color(0xFF2f8d5c),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    _shareToCommunity(context, issue['_id'].toString(), 'Expert');
                                  },
                                  icon: const Icon(Icons.share, size: 16),
                                  label: const Text('এই সমাধানটি কমিউনিটিতে শেয়ার করুন', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ]
                          )
                        )
                      ] else if (issue['status'] == 'Pending_Expert') ...[
                        const SizedBox(height: 12), 
                        const Row(children: [Icon(Icons.pending_actions, color: Colors.orange, size: 14), SizedBox(width: 6), Text('বিশেষজ্ঞের উত্তরের অপেক্ষায়...', style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))])
                      ]
                    ]
                  )
                )).toList()
              ),
          ],
        ),
      ),
      bottomSheet: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF18392d), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -4))]), child: Row(children: [const CircleAvatar(backgroundColor: Color(0xFF2f8d5c), child: Icon(Icons.medical_services, color: Colors.white)), const SizedBox(width: 16), const Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Crop Doctor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)), SizedBox(height: 2), Text('Need help? Send text or photo.', style: TextStyle(color: Colors.white70, fontSize: 11))])), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF18392d), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _showAskAIBottomSheet, child: const Text('Crop Doctor', style: TextStyle(fontWeight: FontWeight.bold)))])),
    );
  }
}

class ExpenseDetailsScreen extends StatelessWidget {
  final String cropName;
  final double totalExpense;
  final List<dynamic> expenses;

  const ExpenseDetailsScreen({super.key, required this.cropName, required this.totalExpense, required this.expenses});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(backgroundColor: const Color(0xFF12362b), elevation: 0, iconTheme: const IconThemeData(color: Colors.white), title: const Text('Expense Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2f8d5c), Color(0xFF64b87a)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Text(cropName, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8), const Text('Total Spent', style: TextStyle(color: Colors.white, fontSize: 16)), const SizedBox(height: 4), Text('৳$totalExpense', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))])),
            const SizedBox(height: 24),
            const Text('All Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
            const SizedBox(height: 12),
            Expanded(child: expenses.isEmpty ? const Center(child: Text('No expenses recorded yet.', style: TextStyle(color: Colors.grey))) : ListView.builder(itemCount: expenses.length, itemBuilder: (context, index) { final exp = expenses[index]; return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)]), child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFedf9f1), child: Icon(Icons.receipt_long, color: Color(0xFF2f8d5c), size: 20)), title: Text(exp['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)), trailing: Text('৳${exp['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF18392d))))); })),
          ],
        ),
      ),
    );
  }
}