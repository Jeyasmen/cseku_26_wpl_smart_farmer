import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'crop_details_screen.dart';
import 'farm_crop_screens.dart'; // RegisterCropScreen ও FarmDetailsScreen-এর জন্য
import 'create_farm_screen.dart'; // CreateFarmScreen-এর জন্য

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

        final loggedInUserName = authProvider.currentUser?.name ?? 'Farmer';

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    loggedInUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
              BottomNavigationBarItem(
                icon: Icon(Icons.agriculture),
                label: 'Farms',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.task_alt),
                label: 'Activities',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
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
      const ProfileScreen(),
    ];
  }
}

// ==========================================
// DASHBOARD SCREEN (DB CONNECTED)
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

  @override
  void initState() {
    super.initState();
    _fetchDashboardSummary();
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
        setState(() {
          _activeFarmsCount = data['activeFarmsCount'] ?? 0;
          _activeCropsCount = data['activeCropsCount'] ?? 0;
          _urgentTasksCount = data['urgentTasksCount'] ?? 0;
          _urgentTasksList = data['urgentTasks'] ?? [];
          _activeCropsList = data['activeCrops'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showUrgentTaskList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Urgent Task Alerts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18392d),
                ),
              ),
              const SizedBox(height: 12),
              _urgentTasksList.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No urgent tasks right now!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : Column(
                      children: _urgentTasksList.map((item) {
                        final farmName = item['farmId'] != null
                            ? item['farmId']['name']
                            : 'Main Farm';
                        return Material(
                          color: Colors.transparent, // ListTile এর স্প্ল্যাশ ওয়ার্নিং ফিক্স করা হলো
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFffebee),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                              ),
                            ),
                            title: Text(
                              item['title'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('$farmName • High Priority'),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CropDetailsScreen(
                                    cropId: item['cropId'] != null
                                        ? item['cropId'].toString()
                                        : '',
                                    itemName: item['title'] ?? 'Crop',
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        );
      },
    );
  }

  void _showCropListDropdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active Crops List',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18392d),
                ),
              ),
              const SizedBox(height: 12),
              _activeCropsList.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No active crops found. Add a crop first!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : Column(
                      children: _activeCropsList.map((crop) {
                        final farmName = crop['farmId'] != null
                            ? crop['farmId']['name']
                            : 'Main Farm';
                        return Material(
                          color: Colors.transparent, // ListTile এর স্প্ল্যাশ ওয়ার্নিং ফিক্স করা হলো
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFedf9f1),
                              child: Icon(Icons.eco, color: Color(0xFF2f8d5c)),
                            ),
                            title: Text(
                              crop['cropType'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Farm: $farmName • Stage: ${crop['currentStage']}',
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CropDetailsScreen(
                                    cropId: crop['_id']
                                        .toString(), // সঠিক cropId পাস করা হলো
                                    itemName: crop['cropType'] ?? 'Crop',
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.currentUser?.name ?? 'Farmer';
    final userDistrict = authProvider.currentUser?.district ?? 'Khulna';

    return SafeArea(
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2f8d5c)),
            )
          : RefreshIndicator(
              onRefresh: _fetchDashboardSummary,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2f8d5c), Color(0xFF64b87a)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
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
                          child: Container(
                            height: 90,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF38ef7d), Color(0xFF11998e)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          color: Colors.white70,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          userDistrict,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      '30°C',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.water_drop,
                                          size: 10,
                                          color: Colors.white70,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          'Hum: 78%',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.air,
                                          size: 10,
                                          color: Colors.white70,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          'Wind: 12km/h',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Partly Cloudy',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white70,
                                        fontStyle: FontStyle.italic,
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
                    const SizedBox(height: 20),

                    // Pre-Farming AI Advisor Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF18392d), Color(0xFF2f8d5c)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Colors.amber,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'AI Crop Advisor',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Check feasibility before starting a new crop',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF18392d),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Opening AI Feasibility Checker...',
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Check',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // DASHBOARD TITLE & SECTIONS
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18392d),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // SECTION 1: URGENT TASK ALERT
                    InkWell(
                      onTap: () => _showUrgentTaskList(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Urgent Task Alert',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF18392d),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_urgentTasksCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'View',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // SECTION 2: ACTIVE CROPS
                    InkWell(
                      onTap: () => _showCropListDropdown(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFedf9f1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.eco,
                                color: Color(0xFF2f8d5c),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Active Crops',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF18392d),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2f8d5c),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_activeCropsCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.grey,
                            ),
                          ],
                        ),
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFedf9f1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.agriculture,
                                color: Color(0xFF2f8d5c),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Active Farms',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF18392d),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2f8d5c),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_activeFarmsCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🚀 SIDE-BY-SIDE BUTTONS (Add Farm & Add Crop)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF18392d),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateFarmScreen(),
                                ),
                              );
                              _fetchDashboardSummary();
                            },
                            icon: const Icon(Icons.add_business, size: 18),
                            label: const Text(
                              'Add Farm',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2f8d5c),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterCropScreen(),
                                ),
                              );
                              _fetchDashboardSummary();
                            },
                            icon: const Icon(Icons.eco, size: 18),
                            label: const Text(
                              'Add Crop',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
        title: const Text(
          'My Farms & Expenses',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF12362b),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2f8d5c)),
            )
          : _userFarms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.agriculture, size: 60, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'No farms created yet!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2f8d5c),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateFarmScreen(),
                        ),
                      );
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFedf9f1),
                        child: Icon(Icons.landscape, color: Color(0xFF2f8d5c)),
                      ),
                      title: Text(
                        farmName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF18392d),
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📍 Location: $location ($landSize $unit)'),
                            const SizedBox(height: 2),
                            Text(
                              '💰 Total Expense: ৳$totalExpense',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2f8d5c),
                              ),
                            ),
                          ],
                        ),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      ),
                      // 🚀 ঠিক এখানেই Navigation কোডটি যোগ করা হয়েছে
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FarmDetailsScreen(
                              farmId: farmId,
                              farmName: farmName,
                            ),
                          ),
                        );
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
      child: Text(
        'Unified Activities',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return Center(
          child: ElevatedButton(
            onPressed: () {
              authProvider.signout();
              Navigator.of(context).pushReplacementNamed('/auth');
            },
            child: const Text('Sign Out'),
          ),
        );
      },
    );
  }
}
