import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'crop_details_screen.dart';
import 'farm_crop_screens.dart';
import 'create_farm_screen.dart';
import 'community_screen.dart'; // 🚀 আপনার ফাইলের লোকেশন অনুযায়ী পাথ ঠিক করে নেবেন

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/auth');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 🚀 ইউজারের ডেটা এবং প্রোফাইল পিকচার ডিকোড করা হচ্ছে
        final user = authProvider.currentUser;
        final loggedInUserName = user?.name ?? 'Farmer';
        Uint8List? displayImage;
        if (user?.profilePicture != null && user!.profilePicture!.isNotEmpty) {
          try {
            displayImage = base64Decode(user.profilePicture!);
          } catch (e) {}
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF3faf4),
          appBar: AppBar(
            backgroundColor: const Color(0xFF12362b),
            elevation: 0,
            title: const Text(
              'Smart Farmer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              // 🚀 নামের পাশে প্রোফাইল ছবি এবং ট্যাপ করলে প্রোফাইলে যাওয়ার সুবিধা
              GestureDetector(
                onTap: () => _changeTab(4), // ৫ নম্বর ট্যাব (ইনডেক্স 4) হলো প্রোফাইল
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        loggedInUserName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFedf9f1),
                        backgroundImage: displayImage != null ? MemoryImage(displayImage) : null,
                        child: displayImage == null 
                          ? const Icon(Icons.person, size: 20, color: Color(0xFF2f8d5c)) 
                          : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: _buildScreens()[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            backgroundColor: const Color(0xFF12362b),
            selectedItemColor: const Color(0xFF7ec98b),
            unselectedItemColor: const Color(0xFF8fa496),
            type: BottomNavigationBarType.fixed,
            onTap: _changeTab,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.agriculture), label: 'Farms'),
              BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Activities'),
              BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Community'), // 🚀 Community Tab
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }

  // 🚀 এখানে CommunityScreen যুক্ত করা হলো
  List<Widget> _buildScreens() {
    return [
      DashboardScreen(onNavigateToFarms: () => _changeTab(1)),
      const FarmsScreen(),
      const ActivitiesScreen(),
      const CommunityScreen(), // 🚀 3rd index
      const ProfileScreen(),   // 🚀 4th index
    ];
  }
}

// ==========================================
// DASHBOARD SCREEN (DB CONNECTED + WEATHER) 🚀
// ==========================================
class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToFarms;
  const DashboardScreen({super.key, required this.onNavigateToFarms});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  int _activeFarmsCount = 0;
  int _activeCropsCount = 0;
  int _urgentTasksCount = 0;
  List<dynamic> _urgentTasksList = [];
  List<dynamic> _activeCropsList = [];

  // Weather State Variables
  String _weatherTemp = '--°C';
  String _weatherHum = 'Hum: --%';
  String _weatherWind = 'Wind: --km/h';
  String _weatherCond = 'Loading...';
  String _weatherLocation = '...';

  // 🚀 ড্রপডাউনের স্টেট ধরে রাখার জন্য
  bool _isUrgentTasksExpanded = false;
  bool _isActiveCropsExpanded = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchDashboardSummary(), _fetchWeather()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchWeather() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/weather'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _weatherTemp = '${data['temp']}°C';
            _weatherHum = 'Hum: ${data['humidity']}%';
            _weatherWind = 'Wind: ${data['windSpeed']}km/h';
            _weatherCond = data['condition'] ?? 'Unknown';
            _weatherLocation = data['location'] ?? 'Location';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherCond = 'Failed to load';
        });
      }
    }
  }

  Future<void> _fetchDashboardSummary() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/farmer/dashboard-summary'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _activeFarmsCount = data['activeFarmsCount'] ?? 0;
            _activeCropsCount = data['activeCropsCount'] ?? 0;
            _urgentTasksCount = data['urgentTasksCount'] ?? 0;
            _urgentTasksList = data['urgentTasks'] ?? [];
            _activeCropsList = data['activeCrops'] ?? [];
          });
        }
      }
    } catch (e) {
      // Handle Error
    }
  }

  // 🌍 🚀 লাইভ চ্যাটবক্স (Live Chatbox) - Global AI Pre-Planting Advisor
  void _showGlobalAIAdvisor(BuildContext context) {
    final questionController = TextEditingController();
    final scrollController = ScrollController();
    bool isAILoading = false;
    List<Map<String, String>> messages = []; 

    void scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(modalContext).size.height * 0.85,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF3faf4),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // --- Header ---
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.psychology, color: Color(0xFF2f8d5c), size: 28),
                            SizedBox(width: 8),
                            Text(
                              'স্মার্ট কৃষি পরামর্শক 👨‍🌾',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF18392d),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'ফসল বোনার আগে মাটির ধরন ও লোকেশন অনুযায়ী সেরা সাজেশন নিন!',
                      style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                    ),
                  ),
                  const Divider(height: 20, thickness: 1),

                  // --- Chat Message List ---
                  Expanded(
                    child: messages.isEmpty
                        ? const Center(
                            child: Text(
                              'আপনার প্রশ্ন নিচে লিখুন...\n(যেমন: "খুলনায় বেলে-দোঁয়াশ মাটিতে তরমুজ চাষ করা যাবে?")',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isUser = msg['sender'] == 'user';
                              return Align(
                                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(modalContext).size.width * 0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUser ? const Color(0xFF2f8d5c) : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
                                      bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                                    ),
                                    border: isUser ? null : Border.all(color: const Color(0xFFcce8d9)),
                                    boxShadow: [
                                      if (!isUser)
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 4,
                                        ),
                                    ],
                                  ),
                                  child: Text(
                                    msg['text']!,
                                    style: TextStyle(
                                      color: isUser ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // --- AI Loading Indicator ---
                  if (isAILoading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          SizedBox(width: 16),
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Color(0xFF2f8d5c), strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'AI চিন্তা করছে...',
                            style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),

                  // --- Chat Input Field ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: questionController,
                            maxLines: 3,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'প্রশ্ন লিখুন...',
                              filled: true,
                              fillColor: const Color(0xFFF3faf4),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isAILoading ? Colors.grey : const Color(0xFF2f8d5c),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: isAILoading
                                ? null
                                : () async {
                                    final text = questionController.text.trim();
                                    if (text.isEmpty) return;

                                    List<Map<String, String>> chatHistory = List.from(messages);

                                    setModalState(() {
                                      messages.add({'sender': 'user', 'text': text});
                                      isAILoading = true;
                                    });
                                    questionController.clear();
                                    scrollToBottom();

                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);

                                    try {
                                      final res = await http.post(
                                        Uri.parse('http://localhost:5000/api/ai/general-advisor'),
                                        headers: {
                                          'Content-Type': 'application/json',
                                          'Authorization': 'Bearer ${authProvider.token}',
                                        },
                                        body: jsonEncode({
                                          'question': text,
                                          'history': chatHistory,
                                        }),
                                      );

                                      if (res.statusCode == 200) {
                                        final data = jsonDecode(res.body);
                                        setModalState(() {
                                          messages.add({'sender': 'ai', 'text': data['answer']});
                                        });
                                      } else {
                                        setModalState(() {
                                          messages.add({'sender': 'ai', 'text': 'সার্ভারে সমস্যা হচ্ছে, একটু পর আবার চেষ্টা করুন।'});
                                        });
                                      }
                                    } catch (e) {
                                      setModalState(() {
                                        messages.add({'sender': 'ai', 'text': 'ইন্টারনেট কানেকশন চেক করুন।'});
                                      });
                                    } finally {
                                      setModalState(() => isAILoading = false);
                                      scrollToBottom();
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
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
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.currentUser?.name ?? 'Farmer';

    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2f8d5c)))
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP SECTION: Welcome Card & Weather Card
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Container(
                            height: 90,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF2f8d5c), Color(0xFF64b87a)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Welcome back,', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text(userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: Container(
                            height: 90,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF38ef7d), Color(0xFF11998e)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(children: [const Icon(Icons.location_on, color: Colors.white70, size: 12), const SizedBox(width: 2), Text(_weatherLocation, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)]),
                                    const SizedBox(height: 2),
                                    Text(_weatherTemp, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(children: [const Icon(Icons.water_drop, size: 10, color: Colors.white70), const SizedBox(width: 2), Text(_weatherHum, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600))]),
                                    const SizedBox(height: 2),
                                    Row(children: [const Icon(Icons.air, size: 10, color: Colors.white70), const SizedBox(width: 2), Text(_weatherWind, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600))]),
                                    const SizedBox(height: 2),
                                    Text(_weatherCond, style: const TextStyle(fontSize: 9, color: Colors.white70, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Pre-Farming AI Advisor Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF18392d), Color(0xFF2f8d5c)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.amber, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('স্মার্ট কৃষি পরামর্শক', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                SizedBox(height: 2),
                                Text('ফসল বোনার আগে মাটির ধরন ও লোকেশন অনুযায়ী সাজেশন নিন', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF18392d), padding: const EdgeInsets.symmetric(horizontal: 12)),
                            onPressed: () => _showGlobalAIAdvisor(context),
                            child: const Text('পরামর্শ নিন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // DASHBOARD TITLE & SECTIONS
                    const Text('Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                    const SizedBox(height: 12),

                    // 🚀 SECTION 1: URGENT TASK ALERT (INLINE EXPANDABLE)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _isUrgentTasksExpanded = !_isUrgentTasksExpanded),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(child: Text('Urgent Task Alert', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF18392d)))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                    child: Text('$_urgentTasksCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(_isUrgentTasksExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: Colors.red),
                                ],
                              ),
                            ),
                          ),
                          if (_isUrgentTasksExpanded) ...[
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Divider(height: 1)),
                            Padding(
                              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
                              child: _urgentTasksList.isEmpty
                                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No urgent tasks right now!', style: TextStyle(color: Colors.grey)))
                                  : Column(
                                      children: _urgentTasksList.map((item) {
                                        final farmName = item['farmId'] != null ? item['farmId']['name'] : 'Main Farm';
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const CircleAvatar(backgroundColor: Color(0xFFffebee), child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16)),
                                          title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          subtitle: Text('$farmName • High Priority', style: const TextStyle(fontSize: 12)),
                                          trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                          onTap: () {
                                            Navigator.push(context, MaterialPageRoute(builder: (_) => CropDetailsScreen(cropId: item['cropId'] != null ? item['cropId'].toString() : '', itemName: item['title'] ?? 'Crop')));
                                          },
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 🚀 SECTION 2: ACTIVE CROPS (INLINE EXPANDABLE)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _isActiveCropsExpanded = !_isActiveCropsExpanded),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFFedf9f1), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.eco, color: Color(0xFF2f8d5c), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(child: Text('Active Crops', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF18392d)))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFF2f8d5c), borderRadius: BorderRadius.circular(10)),
                                    child: Text('$_activeCropsCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(_isActiveCropsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                          if (_isActiveCropsExpanded) ...[
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Divider(height: 1)),
                            Padding(
                              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
                              child: _activeCropsList.isEmpty
                                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No active crops found. Add a crop first!', style: TextStyle(color: Colors.grey)))
                                  : Column(
                                      children: _activeCropsList.map((crop) {
                                        final farmName = crop['farmId'] != null ? crop['farmId']['name'] : 'Main Farm';
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const CircleAvatar(backgroundColor: Color(0xFFedf9f1), child: Icon(Icons.eco, color: Color(0xFF2f8d5c), size: 16)),
                                          title: Text(crop['cropType'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          subtitle: Text('Farm: $farmName • Stage: ${crop['currentStage']}', style: const TextStyle(fontSize: 12)),
                                          trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                          onTap: () {
                                            Navigator.push(context, MaterialPageRoute(builder: (_) => CropDetailsScreen(cropId: crop['_id'].toString(), itemName: crop['cropType'] ?? 'Crop')));
                                          },
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // SECTION 3: ACTIVE FARMS
                    InkWell(
                      onTap: widget.onNavigateToFarms,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFFedf9f1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.agriculture, color: Color(0xFF2f8d5c), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('Active Farms', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF18392d)))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFF2f8d5c), borderRadius: BorderRadius.circular(10)),
                              child: Text('$_activeFarmsCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // SIDE-BY-SIDE BUTTONS (Add Farm & Add Crop)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF18392d),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFarmScreen()));
                              _refreshData();
                            },
                            icon: const Icon(Icons.add_business, size: 18),
                            label: const Text('Add Farm', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2f8d5c),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterCropScreen()));
                              _refreshData();
                            },
                            icon: const Icon(Icons.eco, size: 18),
                            label: const Text('Add Crop', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
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

// ==========================================
// FARMS SCREEN (DATABASE CONNECTED WITH EXPENSE)
// ==========================================
class FarmsScreen extends StatefulWidget {
  const FarmsScreen({super.key});

  @override
  State<FarmsScreen> createState() => _FarmsScreenState();
}

class _FarmsScreenState extends State<FarmsScreen> {
  List<dynamic> _userFarms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserFarmsWithExpenses();
  }

  Future<void> _fetchUserFarmsWithExpenses() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/farms/my-farms-with-expenses'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userFarms = data;
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
        title: const Text('My Farms & Expenses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF12362b),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2f8d5c)))
          : _userFarms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.agriculture, size: 60, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No farms created yet!', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white),
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFarmScreen()));
                      _fetchUserFarmsWithExpenses();
                    },
                    child: const Text('Create Farm Now'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchUserFarmsWithExpenses,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _userFarms.length,
                itemBuilder: (context, index) {
                  final farm = _userFarms[index];
                  final farmId = farm['_id'].toString();
                  final farmName = farm['name'] ?? 'Farm';
                  final location = farm['location'] ?? 'Location not set';
                  final totalExpense = farm['totalExpense'] ?? 0;
                  final landSize = farm['landSize'] ?? 0;
                  final unit = farm['unit'] ?? 'Acres';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: const CircleAvatar(backgroundColor: Color(0xFFedf9f1), child: Icon(Icons.landscape, color: Color(0xFF2f8d5c))),
                      title: Text(farmName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF18392d))),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📍 Location: $location ($landSize $unit)'),
                            const SizedBox(height: 2),
                            Text('💰 Total Expense: ৳$totalExpense', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2f8d5c))),
                          ],
                        ),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FarmDetailsScreen(farmId: farmId, farmName: farmName)));
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ==========================================
// OTHER TABS PLACEHOLDERS
// ==========================================
class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Unified Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

// ==========================================
// PROFILE SCREEN (Beautiful Design + Bio + Picture)
// ==========================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showEditProfileModal(BuildContext context, AuthProvider authProvider) {
    final nameController = TextEditingController(text: authProvider.currentUser?.name ?? '');
    final phoneController = TextEditingController(text: authProvider.currentUser?.phone ?? '');
    final villageController = TextEditingController(text: authProvider.currentUser?.village ?? '');
    final districtController = TextEditingController(text: authProvider.currentUser?.district ?? '');
    final bioController = TextEditingController(text: authProvider.currentUser?.bio ?? ''); 

    String? base64Image = authProvider.currentUser?.profilePicture;
    Uint8List? imageBytes;

    if (base64Image != null && base64Image!.isNotEmpty) {
      try { imageBytes = base64Decode(base64Image!); } catch (e) {}
    }

    bool isSaving = false;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                    const SizedBox(height: 16),
                    
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
                          if (pickedFile != null) {
                            final bytes = await pickedFile.readAsBytes();
                            setModalState(() {
                              imageBytes = bytes;
                              base64Image = base64Encode(bytes);
                            });
                          }
                        },
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFFedf9f1),
                          backgroundImage: imageBytes != null ? MemoryImage(imageBytes!) : null,
                          child: imageBytes == null ? const Icon(Icons.camera_alt, color: Color(0xFF2f8d5c), size: 30) : null,
                        ),
                      ),
                    ),
                    const Center(child: Padding(padding: EdgeInsets.only(top: 8), child: Text('Tap to change photo', style: TextStyle(fontSize: 11, color: Colors.grey)))),
                    const SizedBox(height: 16),
                    
                    TextField(controller: nameController, decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextField(controller: bioController, maxLines: 2, decoration: InputDecoration(labelText: 'Bio (About you/your farm)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextField(controller: villageController, decoration: InputDecoration(labelText: 'Village/Thana', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextField(controller: districtController, decoration: InputDecoration(labelText: 'District', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: isSaving ? null : () async {
                          if (nameController.text.isEmpty) return;
                          setModalState(() => isSaving = true);
                          
                          final success = await authProvider.updateProfile(
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            village: villageController.text.trim(),
                            district: districtController.text.trim(),
                            bio: bioController.text.trim(),
                            profilePicture: base64Image ?? '', 
                          );

                          if (success && mounted) {
                            Navigator.pop(modalContext);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!'), backgroundColor: Color(0xFF2f8d5c)));
                          } else {
                            setModalState(() => isSaving = false);
                          }
                        },
                        child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> _deleteAccount(BuildContext context, AuthProvider authProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('Are you absolutely sure? This will permanently delete your account, all your farms, and crop data. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Delete Forever', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirm == true) {
      final success = await authProvider.deleteAccount();
      if (success && context.mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;
        Uint8List? displayImage;
        if (user?.profilePicture != null && user!.profilePicture!.isNotEmpty) {
          try { displayImage = base64Decode(user.profilePicture!); } catch (e) {}
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFFedf9f1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2f8d5c), width: 3),
                  image: displayImage != null ? DecorationImage(image: MemoryImage(displayImage), fit: BoxFit.cover) : null,
                ),
                child: displayImage == null ? const Icon(Icons.person, size: 50, color: Color(0xFF2f8d5c)) : null,
              ),
              const SizedBox(height: 16),
              Text(user?.name ?? 'Unknown Farmer', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
              const SizedBox(height: 4),
              Text(user?.email ?? 'No email', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 12),
              
              if (user?.bio != null && user!.bio!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Text(
                    '"${user.bio}"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                  ),
                ),

              const SizedBox(height: 30),

              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
                child: Column(
                  children: [
                    ListTile(leading: const Icon(Icons.phone, color: Color(0xFF2f8d5c)), title: const Text('Phone Number', style: TextStyle(fontSize: 12, color: Colors.grey)), subtitle: Text(user?.phone ?? 'Not set', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87))),
                    const Divider(height: 1, indent: 60),
                    ListTile(leading: const Icon(Icons.location_on, color: Color(0xFF2f8d5c)), title: const Text('Location', style: TextStyle(fontSize: 12, color: Colors.grey)), subtitle: Text('${user?.village ?? ''}, ${user?.district ?? 'Khulna'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87))),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Align(alignment: Alignment.centerLeft, child: Text('Account Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF18392d)))),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
                child: Column(
                  children: [
                    ListTile(leading: const Icon(Icons.edit, color: Colors.blueGrey), title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)), trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey), onTap: () => _showEditProfileModal(context, authProvider)),
                    const Divider(height: 1, indent: 60),
                    ListTile(leading: const Icon(Icons.logout, color: Colors.orange), title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600)), trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey), onTap: () { authProvider.signout(); Navigator.of(context).pushReplacementNamed('/auth'); }),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              TextButton.icon(onPressed: () => _deleteAccount(context, authProvider), icon: const Icon(Icons.delete_forever, color: Colors.red), label: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
            ],
          ),
        );
      },
    );
  }
}