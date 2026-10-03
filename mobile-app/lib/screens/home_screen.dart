import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../providers/auth_provider.dart';
import 'crop_details_screen.dart';
import 'farm_crop_screens.dart';
import 'create_farm_screen.dart';
import 'community_screen.dart';

// 📞 হটলাইন কল এবং 💬 হোয়াটসঅ্যাপ ওপেন করার হেল্পার
void _openExternalUrl(String url) {
  html.window.open(url, '_blank');
}

String _formatPhoneForWhatsApp(String rawPhone) {
  String digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('01') && digits.length == 11) {
    return '88$digits';
  }
  return digits;
}

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
              // 💬 বিশেষজ্ঞের সাথে মেসেজ ইনবক্স বাটন
              IconButton(
                icon: const Icon(Icons.mark_chat_unread_outlined, color: Colors.white, size: 22),
                tooltip: 'কৃষি বিশেষজ্ঞের মেসেজ ইনবক্স',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConversationsListScreen()),
                  );
                },
              ),
              GestureDetector(
                onTap: () => _changeTab(4),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, right: 16),
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
              BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Community'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildScreens() {
    return [
      DashboardScreen(onNavigateToFarms: () => _changeTab(1)),
      const FarmsScreen(),
      const ActivitiesScreen(),
      const CommunityScreen(),
      const ProfileScreen(),
    ];
  }
}

// ==========================================
// DASHBOARD SCREEN (DB CONNECTED + WEATHER + VOICE + EXPERT HELPDESK) 🚀
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

  List<dynamic> _weatherDataList = [];
  bool _isWeatherLoading = true;
  String? _selectedLocation;

  bool _isUrgentTasksExpanded = false;
  bool _isActiveCropsExpanded = false;

  // 🔊 স্পষ্ট বাংলা অডিও প্লেয়ার
  final SmartBengaliSpeaker _speaker = SmartBengaliSpeaker();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _speaker.stop();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (mounted) setState(() => _isLoading = true);
    await Future.wait([_fetchDashboardSummary(), _fetchWeather()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchWeather() async {
    if (mounted) setState(() => _isWeatherLoading = true);
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
            _weatherDataList = data;
            _isWeatherLoading = false;
            if (_weatherDataList.isNotEmpty && _selectedLocation == null) {
              final homeData = _weatherDataList.firstWhere(
                (w) => w['isHome'] == true,
                orElse: () => _weatherDataList.first,
              );
              _selectedLocation = homeData['location'];
            }
          });
        }
      } else {
        if (mounted) setState(() => _isWeatherLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isWeatherLoading = false);
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
    } catch (e) {}
  }

  String _getWeatherEmoji(String conditionBn) {
    if (conditionBn.contains('বজ্রঝড়')) return '⛈️';
    if (conditionBn.contains('বৃষ্টি')) return '🌧️';
    if (conditionBn.contains('শিলাবৃষ্টি')) return '🌨️';
    if (conditionBn.contains('মেঘলা')) return '☁️';
    if (conditionBn.contains('রৌদ্রোজ্জ্বল') || conditionBn.contains('পরিষ্কার')) return '☀️';
    if (conditionBn.contains('কুয়াশা')) return '🌫️';
    return '⛅';
  }

  List<Color> _getWeatherGradient(String conditionBn) {
    if (conditionBn.contains('বৃষ্টি') || conditionBn.contains('বজ্রঝড়') || conditionBn.contains('শিলাবৃষ্টি')) {
      return [const Color(0xFF283E51), const Color(0xFF4B79A1)];
    } else if (conditionBn.contains('মেঘলা') || conditionBn.contains('কুয়াশা')) {
      return [const Color(0xFF606c88), const Color(0xFF3f4c6b)];
    } else {
      return [const Color(0xFF2193b0), const Color(0xFF6dd5ed)];
    }
  }

  // 🌍 স্মার্ট কৃষি পরামর্শক (স্পষ্ট বাংলা ভয়েসসহ)
  void _showGlobalAIAdvisor(BuildContext context) {
    final questionController = TextEditingController();
    final scrollController = ScrollController();
    bool isAdvisorLoading = false;
    List<Map<String, String>> messages = [];

    final stt.SpeechToText speech = stt.SpeechToText();
    bool isListening = false;

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
            void listen() async {
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
                    localeId: 'bn_BD',
                    onResult: (val) => setModalState(() {
                      questionController.text = val.recognizedWords;
                    }),
                  );
                }
              } else {
                setModalState(() => isListening = false);
                speech.stop();
              }
            }

            return Container(
              height: MediaQuery.of(modalContext).size.height * 0.85,
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Color(0xFFF3faf4),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
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
                              'স্মার্ট কৃষি পরামর্শক 🌾',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
                            ),
                          ],
                        ),
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
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'ফসল বোনার আগে মাটির ধরন ও লোকেশন অনুযায়ী সেরা পরামর্শ নিন!',
                      style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                    ),
                  ),
                  const Divider(height: 20, thickness: 1),
                  Expanded(
                    child: messages.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text(
                                'আপনার প্রশ্ন নিচে লিখুন অথবা মাইকে বলুন...\n(যেমন: "খুলনায় বেলে-দোআঁশ মাটিতে তরমুজ চাষ করা যাবে?")',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
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
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(modalContext).size.width * 0.78),
                                  decoration: BoxDecoration(
                                    color: isUser ? const Color(0xFF2f8d5c) : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
                                      bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                                    ),
                                    border: isUser ? null : Border.all(color: const Color(0xFFcce8d9)),
                                    boxShadow: [if (!isUser) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          msg['text']!,
                                          style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 14, height: 1.4),
                                        ),
                                      ),
                                      if (!isUser)
                                        InkWell(
                                          onTap: () => _speaker.speak(msg['text']!),
                                          child: const Padding(
                                            padding: EdgeInsets.only(left: 8.0),
                                            child: Icon(Icons.volume_up, size: 20, color: Color(0xFF2f8d5c)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (isAdvisorLoading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          SizedBox(width: 16),
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Color(0xFF2f8d5c), strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('আপনার তথ্যের ভিত্তিতে পরামর্শ তৈরি হচ্ছে...', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
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
                              hintText: 'আপনার প্রশ্ন লিখুন...',
                              filled: true,
                              fillColor: const Color(0xFFF3faf4),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: isListening ? Colors.redAccent : const Color(0xFFeef7f2),
                          child: IconButton(
                            icon: Icon(isListening ? Icons.mic : Icons.mic_none, color: isListening ? Colors.white : const Color(0xFF2f8d5c), size: 20),
                            onPressed: listen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: isAdvisorLoading ? Colors.grey : const Color(0xFF2f8d5c),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: isAdvisorLoading
                                ? null
                                : () async {
                                    final text = questionController.text.trim();
                                    if (text.isEmpty) return;

                                    if (isListening) {
                                      speech.stop();
                                      setModalState(() => isListening = false);
                                    }
                                    _speaker.stop();

                                    List<Map<String, String>> chatHistory = List.from(messages);
                                    setModalState(() {
                                      messages.add({'sender': 'user', 'text': text});
                                      isAdvisorLoading = true;
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
                                        body: jsonEncode({'question': text, 'history': chatHistory}),
                                      );
                                      if (res.statusCode == 200) {
                                        final data = jsonDecode(res.body);
                                        final ans = data['answer']?.toString() ?? '';
                                        setModalState(() {
                                          messages.add({'sender': 'ai', 'text': ans});
                                        });
                                        _speaker.speak(ans);
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
                                      setModalState(() => isAdvisorLoading = false);
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
    ).whenComplete(() => _speaker.stop());
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.currentUser?.name ?? 'Farmer';

    Map<String, dynamic>? currentWeather;
    if (_weatherDataList.isNotEmpty) {
      currentWeather = _weatherDataList.firstWhere(
        (w) => w['location'] == _selectedLocation,
        orElse: () => _weatherDataList.first,
      );
    }

    final bool hasAlert = currentWeather?['hasAlert'] == true;
    final String conditionBn = currentWeather?['conditionBn'] ?? 'স্বাভাবিক';
    final String emoji = _getWeatherEmoji(conditionBn);
    final List<Color> bgGradient = _getWeatherGradient(conditionBn);

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
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2f8d5c), Color(0xFF64b87a)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('স্বাগতম,', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text(
                                  userName,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: SizedBox(
                            height: 90,
                            child: _isWeatherLoading
                                ? Container(
                                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14)),
                                    child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                                  )
                                : currentWeather == null
                                    ? Container(
                                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(14)),
                                        child: const Center(child: Text('No weather data', style: TextStyle(fontSize: 10))),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: bgGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  PopupMenuButton<String>(
                                                    initialValue: _selectedLocation,
                                                    onSelected: (String val) => setState(() => _selectedLocation = val),
                                                    color: Colors.white,
                                                    padding: EdgeInsets.zero,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    itemBuilder: (context) => _weatherDataList.map((w) {
                                                      final loc = w['location'] as String;
                                                      return PopupMenuItem<String>(
                                                        value: loc,
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.location_on, size: 16, color: loc == _selectedLocation ? const Color(0xFF2f8d5c) : Colors.grey),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              loc,
                                                              style: TextStyle(
                                                                fontWeight: loc == _selectedLocation ? FontWeight.bold : FontWeight.normal,
                                                                color: const Color(0xFF18392d),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }).toList(),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.location_on, color: Colors.white70, size: 12),
                                                        const SizedBox(width: 2),
                                                        Flexible(
                                                          child: Text(
                                                            currentWeather['location'] ?? 'Unknown',
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (_weatherDataList.length > 1)
                                                          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      Text(emoji, style: const TextStyle(fontSize: 16)),
                                                      const SizedBox(width: 4),
                                                      Text('${currentWeather['temp']}°C', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                if (hasAlert)
                                                  Tooltip(
                                                    message: currentWeather['alertMessage'] ?? '',
                                                    child: Container(
                                                      margin: const EdgeInsets.only(bottom: 2),
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.umbrella, size: 10, color: Colors.white),
                                                          SizedBox(width: 2),
                                                          Text('সতর্কতা', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 2),
                                                Row(children: [const Icon(Icons.water_drop, size: 10, color: Colors.white70), const SizedBox(width: 2), Text('আর্দ্রতা: ${currentWeather['humidity']}%', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600))]),
                                                const SizedBox(height: 2),
                                                Row(children: [const Icon(Icons.air, size: 10, color: Colors.white70), const SizedBox(width: 2), Text('বাতাস: ${currentWeather['windSpeed']}k', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600))]),
                                                const SizedBox(height: 2),
                                                Text(conditionBn, style: const TextStyle(fontSize: 9, color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ۱. স্মার্ট কৃষি পরামর্শক ব্যানার
                    Container(
                      padding: const EdgeInsets.all(15),
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
                                Text('ফসল বোনার আগে মাটির ধরন ও লোকেশন অনুযায়ী পরামর্শ নিন', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF18392d),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () => _showGlobalAIAdvisor(context),
                            child: const Text('পরামর্শ নিন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 👨‍🌾 ২. নতুন: কৃষি কর্মকর্তা হটলাইন ও সহায়তা কার্ড (EXPERT HELPDESK)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FarmerExpertHelpdeskScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFeef7f2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFbce3c8), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2f8d5c),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.support_agent, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'কৃষি বিশেষজ্ঞ হেল্পডেস্ক ও হটলাইন 👨‍🌾',
                                    style: TextStyle(color: Color(0xFF18392d), fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'হটলাইন কল, হোয়াটসঅ্যাপ অথবা সরাসরি মেসেজে কৃষি কর্মকর্তার পরামর্শ নিন',
                                    style: TextStyle(color: Color(0xFF4d6e60), fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 15, color: Color(0xFF2f8d5c)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // DASHBOARD TITLE & SECTIONS
                    const Text('খামারের সারসংক্ষেপ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                    const SizedBox(height: 12),

                    // SECTION 1: URGENT TASK ALERT
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
                                  const Expanded(
                                    child: Text('জরুরি কাজসমূহ (Urgent Tasks)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                                  ),
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
                                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('এই মুহূর্তে কোনো জরুরি কাজ বাকি নেই!', style: TextStyle(color: Colors.grey)))
                                  : Column(
                                      children: _urgentTasksList.map((item) {
                                        final farmName = item['farmId'] != null ? item['farmId']['name'] : 'Main Farm';
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const CircleAvatar(
                                            backgroundColor: Color(0xFFffebee),
                                            child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                                          ),
                                          title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          subtitle: Text('$farmName • জরুরি পরিচর্যা', style: const TextStyle(fontSize: 12)),
                                          trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => CropDetailsScreen(
                                                  cropId: item['cropId'] != null ? item['cropId'].toString() : '',
                                                  itemName: item['title'] ?? 'Crop',
                                                ),
                                              ),
                                            );
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

                    // SECTION 2: ACTIVE CROPS
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
                                  const Expanded(
                                    child: Text('চলমান ফসলসমূহ (Active Crops)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                                  ),
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
                                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('কোনো চলমান ফসল নেই। নতুন ফসল যোগ করুন!', style: TextStyle(color: Colors.grey)))
                                  : Column(
                                      children: _activeCropsList.map((crop) {
                                        final farmName = crop['farmId'] != null ? crop['farmId']['name'] : 'Main Farm';
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const CircleAvatar(
                                            backgroundColor: Color(0xFFedf9f1),
                                            child: Icon(Icons.eco, color: Color(0xFF2f8d5c), size: 16),
                                          ),
                                          title: Text(crop['cropType'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          subtitle: Text('খামার: $farmName • ধাপ: ${crop['currentStage']}', style: const TextStyle(fontSize: 12)),
                                          trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => CropDetailsScreen(
                                                  cropId: crop['_id'].toString(),
                                                  itemName: crop['cropType'] ?? 'Crop',
                                                ),
                                              ),
                                            );
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
                            const Expanded(
                              child: Text('মোট খামার / জমি (Active Farms)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                            ),
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

                    // SIDE-BY-SIDE BUTTONS
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
                            label: const Text('নতুন খামার যোগ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                            label: const Text('নতুন ফসল যোগ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
        if (mounted) {
          setState(() {
            _userFarms = data;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        title: const Text('আমার খামার ও খরচের হিসাব', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
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
                      const Text('এখনো কোনো খামার তৈরি করা হয়নি!', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white),
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFarmScreen()));
                          _fetchUserFarmsWithExpenses();
                        },
                        child: const Text('নতুন খামার তৈরি করুন'),
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
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFedf9f1),
                            child: Icon(Icons.landscape, color: Color(0xFF2f8d5c)),
                          ),
                          title: Text(farmName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF18392d))),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('📍 লোকেশন: $location ($landSize $unit)'),
                                const SizedBox(height: 2),
                                Text('💰 মোট খরচ: ৳$totalExpense', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2f8d5c))),
                              ],
                            ),
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => FarmDetailsScreen(farmId: farmId, farmName: farmName)),
                            ).then((_) => _fetchUserFarmsWithExpenses());
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
// 📅 UNIFIED ACTIVITIES SCREEN (সব ফসলের কাজের তালিকা) 🚀
// ==========================================
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  List<dynamic> _allTasks = [];
  bool _isLoading = true;
  String _filter = 'today'; // 'today' | 'upcoming' | 'completed'
  final SmartBengaliSpeaker _speaker = SmartBengaliSpeaker();

  @override
  void initState() {
    super.initState();
    _fetchAllTasks();
  }

  @override
  void dispose() {
    _speaker.stop();
    super.dispose();
  }

  Future<void> _fetchAllTasks() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse('http://localhost:5000/api/tasks/my'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _allTasks = jsonDecode(res.body) as List;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markTaskCompleted(String taskId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.put(
        Uri.parse('http://localhost:5000/api/tasks/$taskId/complete'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (res.statusCode == 200) {
        _fetchAllTasks();
      }
    } catch (e) {}
  }

  List<dynamic> _getFilteredTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _allTasks.where((t) {
      final isDone = t['status'] == 'Completed';
      if (_filter == 'completed') return isDone;
      if (isDone) return false;

      final dt = DateTime.tryParse(t['scheduledDate']?.toString() ?? '') ?? now;
      final taskDay = DateTime(dt.year, dt.month, dt.day);

      if (_filter == 'today') {
        return !taskDay.isAfter(today) || t['isUrgent'] == true;
      } else {
        return taskDay.isAfter(today);
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredTasks();

    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        title: const Text('সকল ফসলের কাজের তালিকা', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchAllTasks),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                _buildFilterTab('today', 'আজকের ও জরুরি'),
                const SizedBox(width: 8),
                _buildFilterTab('upcoming', 'আগামী কাজ'),
                const SizedBox(width: 8),
                _buildFilterTab('completed', 'সম্পন্ন কাজ'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2f8d5c)))
                : filtered.isEmpty
                    ? const Center(
                        child: Text('এই তালিকায় কোনো কাজ নেই।', style: TextStyle(color: Colors.grey, fontSize: 15)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final task = filtered[index];
                          final isDone = task['status'] == 'Completed';
                          final isUrgent = task['isUrgent'] == true;
                          final cropName = task['cropId'] is Map ? (task['cropId']['cropType'] ?? 'ফসল') : 'ফসল';
                          final farmName = task['farmId'] is Map ? (task['farmId']['name'] ?? '') : '';
                          final date = DateTime.tryParse(task['scheduledDate']?.toString() ?? '') ?? DateTime.now();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: CheckboxListTile(
                              activeColor: const Color(0xFF2f8d5c),
                              value: isDone,
                              onChanged: isDone ? null : (val) {
                                if (val == true) _markTaskCompleted(task['_id'].toString());
                              },
                              secondary: IconButton(
                                icon: const Icon(Icons.volume_up, color: Color(0xFF2f8d5c)),
                                tooltip: 'বাংলায় শুনুন',
                                onPressed: () {
                                  final desc = task['description']?.toString() ?? '';
                                  _speaker.speak('${task['title']}। $desc');
                                },
                              ),
                              title: Text(
                                task['title']?.toString() ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                  color: isDone ? Colors.grey : const Color(0xFF18392d),
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  '🌱 $cropName ${farmName.isNotEmpty ? '($farmName)' : ''} • 📅 ${date.day}/${date.month}/${date.year} ${isUrgent ? '• 🔴 জরুরি' : ''}',
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String key, String label) {
    final isSelected = _filter == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2f8d5c) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFF2f8d5c) : Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF18392d),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PROFILE SCREEN
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

    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        imageBytes = base64Decode(base64Image);
      } catch (e) {}
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
                        onPressed: isSaving
                            ? null
                            : () async {
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
                        child: isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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
          try {
            displayImage = base64Decode(user.profilePicture!);
          } catch (e) {}
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
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.phone, color: Color(0xFF2f8d5c)),
                        title: const Text('Phone Number', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text(user?.phone ?? 'Not set', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                      ),
                      const Divider(height: 1, indent: 60),
                      ListTile(
                        leading: const Icon(Icons.location_on, color: Color(0xFF2f8d5c)),
                        title: const Text('Location', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text('${user?.village ?? ''}, ${user?.district ?? 'Khulna'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Align(alignment: Alignment.centerLeft, child: Text('Account Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF18392d)))),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit, color: Colors.blueGrey),
                        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        onTap: () => _showEditProfileModal(context, authProvider),
                      ),
                      const Divider(height: 1, indent: 60),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.orange),
                        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        onTap: () {
                          authProvider.signout();
                          Navigator.of(context).pushReplacementNamed('/auth');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextButton.icon(
                onPressed: () => _deleteAccount(context, authProvider),
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =========================================================================
// 👨‍🌾 কৃষকের জন্য "কৃষি বিশেষজ্ঞ হেল্পডেস্ক" (হটলাইন কল + হোয়াটসঅ্যাপ + মেসেজ)
// =========================================================================
class FarmerExpertHelpdeskScreen extends StatefulWidget {
  const FarmerExpertHelpdeskScreen({super.key});

  @override
  State<FarmerExpertHelpdeskScreen> createState() => _FarmerExpertHelpdeskScreenState();
}

class _FarmerExpertHelpdeskScreenState extends State<FarmerExpertHelpdeskScreen> {
  List<dynamic> _experts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchExperts();
  }

  Future<void> _fetchExperts() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse('http://localhost:5000/api/experts'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _experts = jsonDecode(res.body) as List;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'কৃষি বিশেষজ্ঞ হেল্পডেস্ক 👨‍🌾',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined, color: Colors.white),
            tooltip: 'আমার মেসেজ ইনবক্স',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConversationsListScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2f8d5c)))
          : _experts.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'বর্তমানে কোনো নিবন্ধিত কৃষি কর্মকর্তা পাওয়া যায়নি।\nঅ্যাডমিন প্যানেল থেকে একজন ইউজারকে Expert হিসেবে নিয়োগ দিন।',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14.5),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _experts.length,
                  itemBuilder: (context, index) {
                    final exp = _experts[index];
                    final bool isOnline = exp['isAvailable'] != false;
                    final String name = exp['name'] ?? 'কৃষি কর্মকর্তা';
                    final String designation = exp['designation'] ?? 'উপজেলা কৃষি কর্মকর্তা';
                    final String specialization = exp['specialization'] ?? 'ফসল ও মাটি বিশেষজ্ঞ';
                    final String district = exp['district'] ?? 'সারাদেশ';
                    final String dutyHours = exp['dutyHours'] ?? 'সকাল ৯টা - বিকাল ৫টা';
                    final String hotline = (exp['hotlineNumber']?.toString().isNotEmpty == true)
                        ? exp['hotlineNumber'].toString()
                        : (exp['phone']?.toString() ?? '');
                    final String whatsapp = (exp['whatsappNumber']?.toString().isNotEmpty == true)
                        ? exp['whatsappNumber'].toString()
                        : hotline;
                    final int solvedCount = exp['resolvedIssuesCount'] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFcce8d9)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 26,
                                backgroundColor: Color(0xFFedf9f1),
                                child: Icon(Icons.person_pin, color: Color(0xFF2f8d5c), size: 32),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.verified, color: Color(0xFF2f8d5c), size: 17),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      designation,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2f8d5c)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'বিশেষজ্ঞতা: $specialization',
                                      style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOnline ? const Color(0xFFedf9f1) : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 8, color: isOnline ? Colors.green : Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      isOnline ? 'অনলাইন' : 'ব্যস্ত',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isOnline ? const Color(0xFF2f8d5c) : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              _buildInfoChip(Icons.location_on_outlined, 'কর্মস্থল: $district'),
                              _buildInfoChip(Icons.access_time, dutyHours),
                              _buildInfoChip(Icons.task_alt, 'সমাধান দিয়েছেন: $solvedCountটি'),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              // 📞 হটলাইন কল বাটন
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF18392d),
                                    side: const BorderSide(color: Color(0xFF2f8d5c)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    if (hotline.isNotEmpty) {
                                      _openExternalUrl('tel:$hotline');
                                    }
                                  },
                                  icon: const Icon(Icons.call, size: 16, color: Color(0xFF2f8d5c)),
                                  label: const Text('হটলাইন কল', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 💬 হোয়াটসঅ্যাপ বাটন
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    if (whatsapp.isNotEmpty) {
                                      final cleanNum = _formatPhoneForWhatsApp(whatsapp);
                                      final msg = Uri.encodeComponent('আসসালামু আলাইকুম স্যার, আমি স্মার্ট ফার্মার অ্যাপ থেকে আমার ফসলের বিষয়ে পরামর্শ চাচ্ছিলাম।');
                                      _openExternalUrl('https://wa.me/$cleanNum?text=$msg');
                                    }
                                  },
                                  icon: const Icon(Icons.chat, size: 16),
                                  label: const Text('হোয়াটসঅ্যাপ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // ✉️ ইন-অ্যাপ মেসেজ বাটন
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF12362b),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DirectChatScreen(
                                          partnerId: exp['_id'].toString(),
                                          partnerName: name,
                                          partnerSubtitle: designation,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.message_outlined, size: 16),
                                  label: const Text('মেসেজ দিন', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.blueGrey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// =========================================================================
// 💬 ইন-অ্যাপ ডিরেক্ট চ্যাট স্ক্রিন (কৃষক ও বিশেষজ্ঞের কথোপকথন)
// =========================================================================
class DirectChatScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String partnerSubtitle;

  const DirectChatScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    this.partnerSubtitle = '',
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _selectedImageBase64;
  Uint8List? _selectedImageBytes;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchMessages(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse('http://localhost:5000/api/messages/${widget.partnerId}'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _messages = jsonDecode(res.body) as List;
          if (!silent) _isLoading = false;
        });
      }
    } catch (e) {
      if (!silent && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty && _selectedImageBase64 == null) return;

    setState(() => _isSending = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final res = await http.post(
        Uri.parse('http://localhost:5000/api/messages/${widget.partnerId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({
          'text': text.isNotEmpty ? text : '📷 ফসলের ছবি পাঠানো হয়েছে',
          'imageBase64': _selectedImageBase64,
        }),
      );

      if (res.statusCode == 201) {
        _msgController.clear();
        setState(() {
          _selectedImageBase64 = null;
          _selectedImageBytes = null;
        });
        _fetchMessages(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('মেসেজ পাঠাতে সমস্যা হয়েছে')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.partnerName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            if (widget.partnerSubtitle.isNotEmpty)
              Text(widget.partnerSubtitle, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2f8d5c)))
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'আপনার ফসলের যেকোনো প্রশ্ন এখানে লিখে বা ছবি তুলে পাঠান।',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final bool isMe = msg['senderId'].toString() != widget.partnerId;
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF2f8d5c) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (msg['imageBase64'] != null && msg['imageBase64'].toString().isNotEmpty) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        base64Decode(msg['imageBase64'].toString()),
                                        height: 150,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Text(
                                    msg['text']?.toString() ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : const Color(0xFF18392d),
                                      fontSize: 14.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_selectedImageBytes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_selectedImageBytes!, width: 50, height: 50, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('ছবি যুক্ত করা হয়েছে', style: TextStyle(fontSize: 13))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() {
                      _selectedImageBase64 = null;
                      _selectedImageBytes = null;
                    }),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate, color: Color(0xFF2f8d5c)),
                  onPressed: () async {
                    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 65);
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      setState(() {
                        _selectedImageBytes = bytes;
                        _selectedImageBase64 = base64Encode(bytes);
                      });
                    }
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: 'আপনার বার্তা লিখুন...',
                      filled: true,
                      fillColor: const Color(0xFFF3faf4),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF2f8d5c),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 📥 মেসেজ ইনবক্স তালিকা স্ক্রিন (CONVERSATIONS LIST)
// =========================================================================
class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse('http://localhost:5000/api/messages/conversations'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _conversations = jsonDecode(res.body) as List;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12362b),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('মেসেজ ইনবক্স', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2f8d5c)))
          : _conversations.isEmpty
              ? const Center(child: Text('এখনো কোনো কথোপকথন শুরু হয়নি।', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final item = _conversations[index];
                    final partner = item['partner'] ?? {};
                    final unread = item['unreadCount'] ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFedf9f1),
                          child: Icon(Icons.person, color: Color(0xFF2f8d5c)),
                        ),
                        title: Text(
                          partner['name']?.toString() ?? 'কৃষি কর্মকর্তা',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF18392d)),
                        ),
                        subtitle: Text(
                          item['lastMessage']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: unread > 0
                            ? CircleAvatar(
                                radius: 11,
                                backgroundColor: Colors.redAccent,
                                child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11)),
                              )
                            : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DirectChatScreen(
                                partnerId: partner['_id'].toString(),
                                partnerName: partner['name']?.toString() ?? '',
                                partnerSubtitle: partner['designation']?.toString() ?? partner['district']?.toString() ?? '',
                              ),
                            ),
                          );
                          _loadConversations();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}