import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class CropDetailsScreen extends StatefulWidget {
  final String cropId; // ডাটাবেস থেকে রিয়েল ডাটা আনার জন্য আইডি লাগবে
  final String itemName;
  
  const CropDetailsScreen({super.key, required this.cropId, required this.itemName});

  @override
  State<CropDetailsScreen> createState() => _CropDetailsScreenState();
}

class _CropDetailsScreenState extends State<CropDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _cropData;
  double _totalExpense = 0.0;
  int _cropAgeDays = 0;
  String _currentStage = 'Germination';
  
  List<dynamic> _todaysTasks = [];
  List<dynamic> _upcomingTasks = [];
  List<dynamic> _expenses = [];
  List<dynamic> _notes = [];

  @override
  void initState() {
    super.initState();
    _fetchCropDetails();
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
        final tasks = data['tasks'] as List;

        // ফসলের বয়স হিসাব করা
        final sowingDate = DateTime.parse(crop['sowingDate'].toString());
        final now = DateTime.now();
        final age = now.difference(sowingDate).inDays;

        // টাস্কগুলোকে আজকের এবং আগামীকালের জন্য ভাগ করা
        final todayTasksList = [];
        final upcomingTasksList = [];

        for (var task in tasks) {
          final taskDate = DateTime.parse(task['scheduledDate'].toString());
          // যদি টাস্কটি আজকের বা অতীতের হয়
          if (taskDate.isBefore(now) || (taskDate.year == now.year && taskDate.month == now.month && taskDate.day == now.day)) {
            todayTasksList.add(task);
          } else {
            upcomingTasksList.add(task);
          }
        }

        if (mounted) {
          setState(() {
            _cropData = crop;
            _totalExpense = (crop['totalExpense'] ?? 0).toDouble();
            _expenses = crop['expenses'] ?? [];
            _notes = crop['diaryNotes'] ?? [];
            _cropAgeDays = age >= 0 ? age : 0;
            _currentStage = crop['currentStage'] ?? 'Germination';
            _todaysTasks = todayTasksList;
            _upcomingTasks = upcomingTasksList;
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

  Future<void> _toggleTaskStatus(String taskId, bool currentStatus) async {
    if (currentStatus) return; // ইতিমধ্যে সম্পন্ন হলে আর কিছু করার নেই
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final res = await http.put(
        Uri.parse('http://localhost:5000/api/tasks/$taskId/complete'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (res.statusCode == 200) {
        _fetchCropDetails(); // টাস্ক আপডেট হলে রিফ্রেশ
      }
    } catch (e) {
      // Error handling
    }
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
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: 'Expense Purpose (e.g. Fertilizer)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Amount (Tk)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
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
                            final res = await http.post(
                              Uri.parse('http://localhost:5000/api/crops/${widget.cropId}/expenses'),
                              headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'},
                              body: jsonEncode({'title': titleController.text, 'amount': amountController.text}),
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
                      child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
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
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(hintText: 'Write your observation here...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
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
                      child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Note', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _navigateToExpenseDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseDetailsScreen(
          cropName: widget.itemName,
          totalExpense: _totalExpense,
          expenses: _expenses,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3faf4),
        appBar: AppBar(backgroundColor: const Color(0xFF12362b), title: Text(widget.itemName, style: const TextStyle(color: Colors.white))),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF2f8d5c))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${widget.itemName} Dashboard', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. STAGE & EXPENSE HEADER
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
                            InkWell(
                              onTap: _showAddExpenseModal,
                              child: const Text('+ Add', style: TextStyle(fontSize: 12, color: Color(0xFF2f8d5c), fontWeight: FontWeight.bold)),
                            ),
                            InkWell(
                              onTap: _navigateToExpenseDetails,
                              child: const Text('Details >', style: TextStyle(fontSize: 12, color: Color(0xFF2f8d5c), fontWeight: FontWeight.bold)),
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

            // 2. TODAY'S ACTIVITIES
            const Text('Today\'s Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
            const SizedBox(height: 12),
            _todaysTasks.isEmpty
              ? const Padding(padding: EdgeInsets.all(8.0), child: Text('No pending tasks for today!', style: TextStyle(color: Colors.grey)))
              : Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]),
                  child: Column(
                    children: _todaysTasks.map((task) {
                      final bool isTaskDone = task['status'] == 'Completed';
                      return CheckboxListTile(
                        activeColor: const Color(0xFF2f8d5c),
                        title: Text(
                          task['title'].toString(),
                          style: TextStyle(fontWeight: FontWeight.bold, decoration: isTaskDone ? TextDecoration.lineThrough : TextDecoration.none, color: isTaskDone ? Colors.grey : const Color(0xFF18392d)),
                        ),
                        subtitle: Text(
                          task['isUrgent'] == true ? 'High Priority' : 'Routine',
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
            const SizedBox(height: 24),

            // 3. UPCOMING ACTIVITIES
            const Text('Upcoming Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
            const SizedBox(height: 12),
            _upcomingTasks.isEmpty
              ? const Padding(padding: EdgeInsets.all(8.0), child: Text('No upcoming tasks.', style: TextStyle(color: Colors.grey)))
              : Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]),
                  child: Column(
                    children: _upcomingTasks.map((task) {
                      final date = DateTime.parse(task['scheduledDate'].toString());
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFedf9f1), child: Icon(Icons.calendar_month, color: Color(0xFF2f8d5c), size: 18)),
                        title: Text(task['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                        subtitle: Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                ),
            const SizedBox(height: 24),

            // 4. FARM DIARY / NOTES SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Farm Diary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                TextButton(onPressed: _showAddNoteModal, child: const Text('Add Note', style: TextStyle(color: Color(0xFF2f8d5c), fontWeight: FontWeight.bold))),
              ],
            ),
            _notes.isEmpty 
              ? const Text('No diary notes added yet.', style: TextStyle(color: Colors.grey))
              : Column(
                  children: _notes.map((note) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFe6f4ea)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)]),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.edit_note, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(note['note']?.toString() ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF4d6e60), height: 1.4))),
                      ],
                    ),
                  )).toList()
                ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF18392d), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -4))]),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: Color(0xFF2f8d5c), child: Icon(Icons.smart_toy, color: Colors.white)),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Crop AI Assistant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 2),
                  Text('Need help? Send text or photo.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF18392d), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {},
              child: const Text('Ask AI', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// EXPENSE DETAILS SCREEN
// ==========================================
class ExpenseDetailsScreen extends StatelessWidget {
  final String cropName;
  final double totalExpense;
  final List<dynamic> expenses;

  const ExpenseDetailsScreen({
    super.key,
    required this.cropName,
    required this.totalExpense,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Expense Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
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
                  Text(cropName, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Total Spent', style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('৳$totalExpense', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('All Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
            const SizedBox(height: 12),
            Expanded(
              child: expenses.isEmpty
                  ? const Center(child: Text('No expenses recorded yet.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final exp = expenses[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)]),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Color(0xFFedf9f1), child: Icon(Icons.receipt_long, color: Color(0xFF2f8d5c), size: 20)),
                            title: Text(exp['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            trailing: Text('৳${exp['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF18392d))),
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